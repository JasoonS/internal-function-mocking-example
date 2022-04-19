let files = Node.Fs.readdirSync("../contracts/abis")

let {startsWith} = module(Js.String2)
let lowerCaseFirstLetter = %raw(`(someString) => someString.charAt(0).toLowerCase() + someString.slice(1)`)
let removePrefixUnderscores = %raw(`(someString) => {
  if (someString.charAt(0) == "_") {
    return someString.slice(1)
  } else {
    return someString
  }
}`)

let formatKeywords = keyword =>
  switch keyword {
  | "to" => "_" ++ keyword
  | _ => keyword->removePrefixUnderscores
  }
let getMmoduleName = fileName => fileName->Js.String2.split(".")->Array.getUnsafe(0)
let getRescriptType = typeString =>
  switch typeString {
  | #"uint32[]" => "array<int>"
  | #uint8
  | #uint16
  | #uint32 => "int"
  | #uint256
  | #uint80
  | #uint128
  | #uint112
  | #int256 => "Ethers.BigNumber.t"
  | #string => "string"
  | #address => "Ethers.ethAddress"
  | #bytes4 => "bytes4"
  | #bytes
  | #bytes32 => "bytes32"
  | #bool => "bool"
  | #"address[]" => "array<Ethers.ethAddress>"
  | t if t->Obj.magic->startsWith("tuple") => "tuple"
  | unknownType =>
    Js.log(`Please handle all types - ${unknownType->Obj.magic} isn't handled by this script.`)
    "unknownType"
  }
type inputParamLayout = NamedTyped | NamedUntyped | UnnamedUntyped

let typeInputs = (inputs, paramLayout: inputParamLayout) => {
  let paramsString = ref("")
  let _ = inputs->Array.mapWithIndex((index, input) => {
    let paramType = input["type"]
    let parameterIsNamed = input["name"] != ""
    let paramName =
      input["name"] == "" ? `param${index->Int.toString}` : input["name"]->formatKeywords

    let rescriptType = getRescriptType(paramType)

    paramsString :=
      paramsString.contents ++
      switch paramLayout {
      | NamedTyped => `${parameterIsNamed ? "~" ++ paramName ++ ":" : ""} ${rescriptType},`
      | NamedUntyped => `${parameterIsNamed ? "~" : ""}${paramName},`
      | UnnamedUntyped => `${paramName},`
      }
  })

  paramsString.contents
}
let typeOutputs = (outputs, functionName) => {
  let paramsString = ref("")
  if outputs->Array.length > 1 {
    let _types = outputs->Array.mapWithIndex((index, output) => {
      let paramType = output["type"]
      let paramName =
        output["name"] == "" ? `param${index->Int.toString}` : output["name"]->formatKeywords

      let rescriptType = getRescriptType(paramType)

      paramsString :=
        paramsString.contents ++
        `
${paramName}: ${rescriptType},`
    })
    `type ${functionName}Return = {${paramsString.contents}
    }`
  } else if outputs->Array.length == 1 {
    let rescriptType = getRescriptType((outputs->Array.getUnsafe(0))["type"])
    `type ${functionName->lowerCaseFirstLetter}Return = ${rescriptType}`
  } else {
    `type ${functionName->lowerCaseFirstLetter}Return`
  }
}

let generateConstructor = (constructorParams, _moduleName) => {
  let typeNamesFull = typeInputs(constructorParams, NamedTyped)
  let typeNames = typeInputs(constructorParams, NamedUntyped)
  let callParams = typeInputs(constructorParams, UnnamedUntyped)
  `let make: (${typeNamesFull}) => JsPromise.t<t> = (${typeNames}) =>
    deployContract${constructorParams
    ->Array.length
    ->Int.toString}(contractName, ${callParams})->Obj.magic

    let makeSmock: (${typeNamesFull}) => JsPromise.t<t> = (${typeNames}) =>
    deployMockContract${constructorParams
    ->Array.length
    ->Int.toString}(contractName, ${callParams})->Obj.magic

    let setVariable: (t, ~name: string, ~value: 'a) => JsPromise.t<unit> = setVariableRaw
    
    `
}

let moduleDictionary: Js.Dict.t<(Js.Dict.t<string>, string)> = Js.Dict.empty()
let _ = files->Array.map(abiFileName => {
  let abiFileContents = `../contracts/abis/${abiFileName}`->Node.Fs.readFileAsUtf8Sync

  let abiFileObject = abiFileContents->Js.Json.parseExn->Obj.magic // use some useful polymorphic magic 🙌

  let moduleName = getMmoduleName(abiFileName)

  let moduleContents = Js.Dict.empty()
  let moduleConstructor = ref(`let make: unit => JsPromise.t<t> = () => deployContract0(contractName)->Obj.magic
    let makeSmock: unit => JsPromise.t<t> = () => deployMockContract0(contractName)->Obj.magic

    let setVariable: (t, ~name: string, ~value: 'a) => JsPromise.t<unit> = setVariableRaw
    `)
  let _processEachItemInAbi = abiFileObject->Array.map(abiItem => {
    let name = abiItem["name"]
    let itemType = abiItem["type"]
    let inputs = abiItem["inputs"]

    switch itemType {
    | #event => Js.log(`we have an event - ${name}`)
    | #function =>
      let outputs = abiItem["outputs"]
      let hasReturnValues = outputs->Array.length > 0
      let stateMutability = abiItem["stateMutability"]
      let typeNames = typeInputs(inputs, NamedTyped)
      let returnType = `${name}Return`->lowerCaseFirstLetter
      let returnTypeDefinition = typeOutputs(outputs, name)
      switch stateMutability {
      | #view | #pure =>
        moduleContents->Js.Dict.set(
          name,
          `
  ${returnTypeDefinition}
  @send
  external ${name->lowerCaseFirstLetter}: (
    t,${typeNames}
  ) => JsPromise.t<${returnType}> = "${name}"
`,
        )
      | _ =>
        let callVersion = hasReturnValues
          ? `
    ${returnTypeDefinition}
    @send @scope("callStatic")
    external ${name}Call: (
      t,${typeNames}
    ) => JsPromise.t<${returnType}> = "${name}"
`
          : ""
        moduleContents->Js.Dict.set(
          name,
          `
  @send
  external ${name}: (
    t,${typeNames}
  ) => JsPromise.t<transaction> = "${name}"
${callVersion}`,
        )
      }
    | #constructor => moduleConstructor := generateConstructor(inputs, moduleName)
    | _ => Js.log2(`We have an unhandled type - ${name} ${itemType->Obj.magic}`, abiItem)
    }
  })
  moduleDictionary->Js.Dict.set(moduleName, (moduleContents, moduleConstructor.contents))
})

let _writeFiles =
  moduleDictionary
  ->Js.Dict.entries
  ->Array.map(((moduleName, (functions, contractConstructor))) => {
    if !(moduleName->Js.String2.endsWith("Mockable")) {
      let optExposedFunctions = moduleDictionary->Js.Dict.get(moduleName ++ "Mockable")
      let exposedFunctionBinding = switch optExposedFunctions {
      | Some((functions, contractConstructor)) =>
        `module Exposed = {
          let contractName = "${moduleName}Mockable"

          ${contractConstructor}
          ${functions->Js.Dict.values->Js.String.concatMany("")}
        }`
      | None => ""
      }

      Node.Fs.writeFileAsUtf8Sync(
        `../contracts/test/library/contracts/${moduleName}.res`,
        `
@@ocaml.warning("-32")
open SmockGeneral
open ContractHelpers
type t = {address: Ethers.ethAddress}
let contractName = "${moduleName}"

let at: Ethers.ethAddress => JsPromise.t<t> = contractAddress =>
  attachToContract(contractName, ~contractAddress)->Obj.magic

${contractConstructor}

${functions->Js.Dict.values->Js.String.concatMany("")}

${exposedFunctionBinding}
`,
      )
    }
  })
