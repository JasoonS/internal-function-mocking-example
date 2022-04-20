// Script still needs work, will break for constructors e.g.
// Also can't handle an edge case where you implement a an overriden pure
// function. Change the interface if possible.

// Will generate the files in this contract/contracts/testing/generated folder.

// Script is still pretty rough, will refine it as needed.

// It assumes a single contract definition in a file.

// TO ADD A FILE TO THIS: add filepath relative to ../contracts/contracts here. e.g. mocks/YieldManagerMock.sol
open Js.String2
open MockablesGenTemplates

let filesToMockInternally = ["longShort/template/LongShort.sol", "staker/template/Staker.sol", "demo/InternalMockExample.sol"]

exception ScriptDoesNotSupportReturnValues(string)

let defaultError = "This script currently only supports functions that return or receive as parameters uints, ints, bools, (nonpayable) addresses, contracts, structs, arrays or strings
          // NO MAPPINGS"
let {contains, containsRe, commafiy} = module(Globals)

let abisToMockExternally = [
  "ERC20Mock",
  "YieldManagerMock",
  "DegenProtocol",
  "LongShort",
  "SyntheticToken",
  "YieldManagerAaveBasic",
  "FloatCapital_v0",
  "TokenFactory",
  "FloatToken",
  "Staker",
  "Treasury_v0",
  "OracleManagerChainlink",
  "OracleManagerMock",
  "LendingPoolAaveMock",
  "LendingPoolAddressesProviderMock",
  "AaveIncentivesControllerMock",
  "InternalMockExample",
]

let convertASTTypeToSolTypeSimple = typeDescriptionStr => {
  switch typeDescriptionStr {
  | t if t->startsWith("contract ") => typeDescriptionStr->replaceByRe(%re("/contract\s+/g"), "")
  | t if t->startsWith("struct ") => typeDescriptionStr->replaceByRe(%re("/struct\s+/g"), "")
  | t => t
  }
}
let convertASTTypeToSolType = (~isDeclaration=true, typeDescriptionStr) => {
  switch typeDescriptionStr {
  | "bool"
  | "address" => typeDescriptionStr
  | "string" => "string calldata "
  | t if t->Globals.containsRe(%re("/\\[/g")) => t ++ " memory" // PARTIAL IMPLEMENTATION FOR ARRAYS
  | t if t->startsWith("uint") => typeDescriptionStr
  | t if t->startsWith("int") => typeDescriptionStr
  | t if t->startsWith("contract ") => typeDescriptionStr->replaceByRe(%re("/contract\s+/g"), "")
  | t if t->startsWith("enum ") => t->replaceByRe(%re("/enum\s+/g"), "")
  | t if t->startsWith("struct ") =>
    typeDescriptionStr
    ->replaceByRe(%re("/struct\s+/g"), "")
    ->replaceByRe(%re("/Mockable/g"), "") ++ (isDeclaration ? " memory " : "")
  | _ => raise(ScriptDoesNotSupportReturnValues(defaultError))
  }
}

let nodeToTypedIdentifier: 'a => Globals.typedIdentifier = node => {
  name: node["name"],
  type_: node["typeDescriptions"]["typeString"],
  storageLocation: node["storageLocation"] == "storage" ? Storage : NotRelevant,
  storageLocationString: node["storageLocation"],
}

let functionVirtualOrPure = nodeStatements => {
  nodeStatements
  ->Array.keep(x => x["nodeType"] == #FunctionDefinition && !(x["name"] == "")) // ignore constructors
  ->Array.keep(x => {
    x["virtual"] || x["pure"]
  })
  ->Array.map(x => {
    let r: Globals.functionType = {
      name: x["name"],
      parameters: x["parameters"]["parameters"]->Array.map(y => y->nodeToTypedIdentifier),
      returnValues: x["returnParameters"]["parameters"]->Array.map(y => y->nodeToTypedIdentifier),
      visibility: x["visibility"] == "public" || x["visibility"] == "external" ? Public : Private,
    }
    (r, x)
  })
}

let modifiers = nodeStatements => {
  nodeStatements
  ->Array.keep(x => x["nodeType"] == #ModifierDefinition)
  ->Array.map(x => {
    let r: Globals.functionType = {
      name: x["name"],
      parameters: x["parameters"]["parameters"]->Array.map(y => y->nodeToTypedIdentifier),
      returnValues: [],
      // TODO: modifiers are always internal ... unnecessary.
      visibility: x["visibility"] == "public" || x["visibility"] == "external" ? Public : Private,
    }
    (r, x)
  })
}

let lineCommentsRe = %re("/\\/\\/[^\\n]*\\n/g")
let blockCommentsRe = %re("/\\/\\*([^*]|[\\r\\n]|(\\*+([^*/]|[\\r\\n])))*\\*+\\//g")

@module("fs") external folderExists: string => bool = "existsSync"
@module("fs") external mkdirSync: (string, 'a) => unit = "mkdirSync"

let _ = `artifacts/contracts/FloatCapital_v0.sol/FloatCapital_v0.json`
@val external requireJson: string => 'a = "require"

let getContractArtifact = fileNameWithoutExtension =>
  requireJson(`../../contracts/abis/${fileNameWithoutExtension}.json`)
let getContractAst = fileNameWithoutExtension =>
  requireJson(`../../contracts/ast/${fileNameWithoutExtension}.json`)

exception BadMatchingBlock
let rec matchingBlockEndIndex = (str, startIndex, count) => {
  let charr = str->charAt(startIndex)
  if charr == "}" && count == 1 {
    startIndex
  } else if charr == "}" && count > 1 {
    matchingBlockEndIndex(str, startIndex + 1, count - 1)
  } else if charr == "{" {
    matchingBlockEndIndex(str, startIndex + 1, count + 1)
  } else if charr != "{" && charr != "}" {
    matchingBlockEndIndex(str, startIndex + 1, count)
  } else {
    raise(BadMatchingBlock)
  }
}

let importRe = %re("/import[^;]+;/g")
let quotesRe = %re(`/"[\S\s]*"/`)

let rec resolveImportLocationRecursive = (array, _import) => {
  switch _import {
  | i if !(i->contains("/")) => array->Array.reduce("", (acc, curr) => acc ++ curr ++ "/") ++ i
  | i if i->startsWith("../") =>
    resolveImportLocationRecursive(
      array->Array.reverse->Array.sliceToEnd(1)->Array.reverse,
      i->substringToEnd(~from=3),
    )
  | i if i->startsWith("./") => resolveImportLocationRecursive(array, i->substringToEnd(~from=2))
  | i => {
      let firstSlashIndex = i->indexOf("/")
      resolveImportLocationRecursive(
        array->Array.concat([i->substring(~from=0, ~to_=firstSlashIndex)]),
        i->substringToEnd(~from=firstSlashIndex + 1),
      )
    }
  }
}

let reduceStrArr = arr => arr->Array.reduce("", (acc, curr) => acc ++ curr)

let parseAbiTypes = types =>
  types->Array.map(i => {
    let r: Globals.typedIdentifier = {
      storageLocation: NotRelevant,
      storageLocationString: "callable",
      type_: i["internalType"],
      name: i["name"],
    }
    r
  })

let parseAbi = abi =>
  abi
  ->Array.keep(n => n["type"] == "function")
  ->Array.map(n => {
    let r: Globals.functionType = {
      name: n["name"],
      visibility: Public,
      parameters: n["inputs"]->parseAbiTypes,
      returnValues: n["outputs"]->parseAbiTypes,
    }
    r
  })

let bindingsDict: HashMap.String.t<string> = HashMap.String.make(~hintSize=10)

abisToMockExternally->Array.forEach(contractName => {
  let abi = getContractArtifact(contractName)
  let functions = abi->parseAbi
  bindingsDict->HashMap.String.set(
    contractName,
    SmockableGen.externalModule(functions, ~contractName),
  )
})

filesToMockInternally->Array.forEach(filePath => {
  let filePathSplit = filePath->split("/")
  let fileName = filePathSplit->Array.getExn(filePathSplit->Array.length - 1)

  let fileNameSplit = fileName->split(".")

  let fileNameWithoutExtension =
    fileNameSplit
    ->Array.slice(
      ~offset=0,
      ~len=if fileNameSplit->Array.length > 1 {
        fileNameSplit->Array.length - 1
      } else {
        fileNameSplit->Array.length
      },
    )
    ->reduceStrArr

  let typeDefContainsFileName = `\\\s${fileNameWithoutExtension}\\\.`->Js.Re.fromString
  let actionOnFileNameTypeDefs = (action, type_) =>
    if type_->containsRe(typeDefContainsFileName) {
      type_->action
    } else {
      type_
    }

  let replaceFileNameTypeDefsWithMockableTypeDefs = actionOnFileNameTypeDefs(type_ =>
    type_->replace(`${fileNameWithoutExtension}.`, `${fileNameWithoutExtension}Mockable.`)
  )
  let removeFileNameFromTypeDefs = actionOnFileNameTypeDefs(type_ =>
    type_->replaceByRe(typeDefContainsFileName, " ")
  )
  let sol = ref(("../contracts/contracts/" ++ filePath)->Node.Fs.readFileAsUtf8Sync)

  let lineCommentsMatch =
    sol.contents
    ->match_(lineCommentsRe)
    ->Option.map(i => i->Array.keep(x => !(x->contains("SPDX-License-Identifier"))))

  let _ = lineCommentsMatch->Option.map(l =>
    l->Array.forEach(i => {
      sol := sol.contents->replace(i, "")
    })
  )

  sol := sol.contents->replaceByRe(blockCommentsRe, "\n")
  let body = sol.contents
  let contractAst = getContractAst(fileNameWithoutExtension)

  let contractDefinition =
    contractAst["nodes"]->Array.keep(x => x["nodeType"] == "ContractDefinition")->Array.getExn(0)

  let mockLogger = ref("")

  let optionalConstructor =
    contractDefinition["nodes"]->Array.keep(x => x["name"] == "")->Array.get(0) // ignore constructors

  let constructor = optionalConstructor->Option.mapWithDefault("", x => {
    let parameters = x["parameters"]["parameters"]->Array.map(y => y->nodeToTypedIdentifier)

    let params =
      parameters
      ->Array.map(x => {
        x.name
      })
      ->commafiy

    let paramsWithTypes =
      parameters
      ->Array.map(x =>
        x.type_->replaceFileNameTypeDefsWithMockableTypeDefs->convertASTTypeToSolType ++
        " " ++
        x.name
      )
      ->commafiy

    MockablesGenTemplates.constructor(~paramsWithTypes, ~params, ~fileNameWithoutExtension)
  })

  // TODO: modify this code so that it also generates exposed interfaces for interal pure fonctions that aren't virtual.
  let allFunctions = functionVirtualOrPure(contractDefinition["nodes"])->Array.map(((
    x,
    original,
  )) => {
    let isPure = original["stateMutability"] == "pure"
    let isExternal = original["visibility"] == "external"

    let indexOfOldFunctionDec = body->indexOf("function " ++ x.name ++ "(")

    let indexOfOldFunctionBodyStart = body->indexOfFrom("{", indexOfOldFunctionDec)

    let originalFunctionDefinition =
      body->substring(~from=indexOfOldFunctionDec, ~to_=indexOfOldFunctionBodyStart + 1)
    let alreadyAnOverride = originalFunctionDefinition->indexOf("override") != -1
    let functionDefinition =
      originalFunctionDefinition->replace("virtual", alreadyAnOverride ? "" : "override")

    let storageParameters = x.parameters->Array.keep(x => x.storageLocation == Storage)

    let mockerParameterCalls =
      x.parameters
      ->Array.map(x => {
        x.storageLocation == Storage ? x.name ++ "_temp1" : x.name
      })
      ->commafiy

    let mockerArguments =
      x.parameters
      ->Array.map(x =>
        x.type_->replaceFileNameTypeDefsWithMockableTypeDefs->convertASTTypeToSolType
      )
      ->commafiy

    let storageParametersFormatted =
      storageParameters
      ->Array.map(x =>
        `
          ${x.type_
          ->removeFileNameFromTypeDefs
          ->convertASTTypeToSolType} ${x.name}_temp1 = ${x.name};
        `
      )
      ->reduceStrArr

    let mockerReturnValues = switch x.returnValues {
    | arr if arr->Array.length > 0 =>
      `returns (${arr
        ->Array.map(x => x.type_->convertASTTypeToSolType ++ " " ++ x.name)
        ->commafiy})`
    | _ => ""
    }

    let exposedCallArguments =
      x.parameters
      ->Array.map(x => {
        let storageLocation = x.storageLocationString == "default" ? "" : x.storageLocationString
        `${x.type_->convertASTTypeToSolTypeSimple} ${storageLocation} ${x.name}`
      })
      ->commafiy
    let stateMutabilityText =
      original["stateMutability"] == "nonpayable" ? "" : original["stateMutability"]
    let exposedFunction = switch x.visibility {
    | Private =>
      `function ${x.name}Exposed(${exposedCallArguments}) external ${stateMutabilityText} ${mockerReturnValues} { return super.${x.name}(${mockerParameterCalls});}
`
    | Public => ""
    }

    let result = isExternal
      ? ""
      : exposedFunction ++ (
          isPure
            ? "\n"
            : functionDefinition ++
              mockableFunctionBody(
                ~functionName=x.name,
                ~storageParameters=storageParametersFormatted,
                ~mockerParameterCalls,
              )
        )

    let mockerReturn =
      x.returnValues
      ->Array.map(y =>
        "abi.decode(\"\",(" ++ y.type_->convertASTTypeToSolType(~isDeclaration=false) ++ "))"
      )
      ->commafiy

    mockLogger :=
      mockLogger.contents ++
      externalMockerFunctionBody(
        ~functionName=x.name,
        ~mockerArguments,
        ~mockerReturnValues,
        ~mockerReturn,
      )

    result
  })

  let importsInFile = body->match_(importRe)
  let importsInFileReplaced = importsInFile->Option.map(i =>
    i->Array.map(x => {
      if !(x->contains("..")) && !(x->contains("./")) {
        x
      } else {
        let impStatement = x->match_(quotesRe)->Option.getExn->Array.getExn(0)
        let impStatement = impStatement->substring(~from=1, ~to_=impStatement->String.length)
        let initialDirStructure = filePath->split("/")
        let initialDirStructure =
          initialDirStructure->Array.slice(~offset=0, ~len=initialDirStructure->Array.length - 1)
        x->replace(
          impStatement,
          "../../" ++ resolveImportLocationRecursive(initialDirStructure, impStatement),
        )
      }
    })
  )

  let _ = importsInFile->Option.map(i =>
    i->Array.forEachWithIndex((index, imp) => {
      sol :=
        sol.contents->replace(imp, importsInFileReplaced->Option.getUnsafe->Array.getUnsafe(index))
    })
  )

  let parentImports =
    importsInFileReplaced->Option.mapWithDefault("", i =>
      i->Array.map(z => z ++ "\n")->reduceStrArr
    )

  mockLogger :=
    internalMockingFileTemplate(
      ~fileNameWithoutExtension,
      ~parentImports,
      ~contractBody=mockLogger.contents,
    )

  let indexOfFirstImports = body->indexOf("import")

  let prefix = body->substring(~from=0, ~to_=indexOfFirstImports) ++ parentImports

  let allFunctionsString = allFunctions->Js.Array2.joinWith("\n")
  let fullBody = allFunctionsString

  let contractMockable = mockingFileTemplate(
    ~prefix,
    ~fileNameWithoutExtension,
    ~fullBody,
    ~constructor,
  )

  let outputDirectory = "../contracts/contracts/testing/generated"
  if !folderExists(outputDirectory) {
    mkdirSync(outputDirectory, {"recursive": true})
  }

  Node.Fs.writeFileAsUtf8Sync(
    `${outputDirectory}/${fileNameWithoutExtension}Mockable.sol`,
    contractMockable,
  )
  Node.Fs.writeFileAsUtf8Sync(
    `${outputDirectory}/${fileNameWithoutExtension}ForInternalMocking.sol`,
    mockLogger.contents,
  )

  let existingModuleDef =
    abisToMockExternally->Array.some(x => x == fileNameWithoutExtension)
      ? bindingsDict->HashMap.String.get(fileNameWithoutExtension)->Option.getExn
      : ""

  bindingsDict->HashMap.String.set(
    fileNameWithoutExtension,
    existingModuleDef ++
    "\n\n" ++
    functionVirtualOrPure(contractDefinition["nodes"])
    ->Array.map(((x, _)) => x)
    ->SmockableGen.internalModule(~contractName=fileNameWithoutExtension),
  )
})

/// Generate rescript smocked interfaces
bindingsDict->HashMap.String.forEach((key, val) => {
  Node.Fs.writeFileAsUtf8Sync(`../contracts/test/library/smock/${key}Smocked.res`, val)
})
