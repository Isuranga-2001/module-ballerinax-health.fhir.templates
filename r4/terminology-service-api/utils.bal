import terminology_service_api.store;

import ballerina/data.jsondata;
import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/persist;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.parser;
import ballerina/regex;

import ballerinacentral/zip;

// Module-level counter for unique file naming
isolated int fileCount = 0;

isolated function validationResultToParameters(international401:Parameters|r4:FHIRError concept) returns international401:Parameters|r4:FHIRError {
    international401:ParametersParameter[] params = [];
    if concept is r4:FHIRError {
        if concept.message().matches(re `Can not find any valid concepts for the code:.*`) {
            params.push({name: "result", valueBoolean: false});
        } else {
            return concept;
        }
    } else {
        if (<international401:ParametersParameter[]>concept.'parameter).length() > 0 {
            foreach var c in <international401:ParametersParameter[]>concept.'parameter {
                _ = c.name == "name" ? params.push({name: "result", valueBoolean: true}) : "";
                _ = c.name == "display" ? params.push(c) : "";
                _ = c.name == "definition" ? params.push(c) : "";
            }
        } else {
            params.push({name: "result", valueBoolean: false});
        }
    }

    return {
        'parameter: params
    };
}

isolated function prepareRequestSearchParameter(map<string[]> params) returns map<r4:RequestSearchParameter[]> {
    map<r4:RequestSearchParameter[]> searchParams = {};
    foreach var 'key in params.keys() {
        match 'key {
            "_id" => {
                searchParams["_id"] = [createRequestSearchParameter("_id", params.get("_id")[0])];
            }

            "name" => {
                searchParams["name"] = [createRequestSearchParameter("name", params.get("name")[0])];
            }

            "title" => {
                searchParams["title"] = [createRequestSearchParameter("title", params.get("title")[0])];
            }

            "url" => {
                searchParams["url"] = [createRequestSearchParameter("url", params.get("url")[0])];
            }

            "version" => {
                r4:RequestSearchParameter[] tempList = [];
                foreach var value in params.get("version") {
                    tempList.push(createRequestSearchParameter("version", value, 'type = r4:STRING));
                }
                searchParams["version"] = tempList;
            }

            "description" => {
                searchParams["description"] = [createRequestSearchParameter("description", params.get("description")[0])];
            }

            "publisher" => {
                searchParams["publisher"] = [createRequestSearchParameter("publisher", params.get("publisher")[0])];
            }

            "status" => {
                r4:RequestSearchParameter[] tempList = [];
                foreach var value in params.get("status") {
                    tempList.push(createRequestSearchParameter("status", value, 'type = r4:REFERENCE));
                }
                searchParams["status"] = tempList;
            }

            "valueSetVersion" => {
                searchParams["valueSetVersion"] = [createRequestSearchParameter("valueSetVersion", params.get("valueSetVersion")[0])];
            }

            "filter" => {
                searchParams["filter"] = [createRequestSearchParameter("filter", params.get("filter")[0])];
            }

            "_count" => {
                searchParams["_count"] = [createRequestSearchParameter("_count", params.get("_count")[0], 'type = r4:NUMBER)];
            }

            "_offset" => {
                searchParams["_offset"] = [createRequestSearchParameter("_offset", params.get("_offset")[0], 'type = r4:NUMBER)];
            }
        }
    }
    return searchParams;
}

isolated function createRequestSearchParameter(string name, string value, r4:FHIRSearchParameterType? 'type = r4:STRING, r4:FHIRSearchParameterModifier? modifier = r4:MODIFIER_EXACT) returns r4:RequestSearchParameter {
    return {name: name, value: value, 'type: r4:STRING, typedValue: {modifier: modifier}};
}

isolated function codeSystemConceptPropertyToParameter(r4:CodeSystemConceptProperty property) returns international401:ParametersParameter {
    international401:ParametersParameter param = {name: "property"};
    international401:ParametersParameter[] part = [];

    if property.valueString is string {
        part.push(
            {name: "code", valueCode: property.code},
            {name: "value", valueString: property.valueString}
        );
    }

    if property.valueCoding is r4:Coding {
        part.push(
            {name: "code", valueCode: property.code},
            {name: "value", valueCoding: property.valueCoding}
        );
    }
    param.part = part;

    return param;
}

isolated function codesystemConceptsToParameters(r4:CodeSystemConcept[]|r4:CodeSystemConcept concepts) returns international401:Parameters {
    international401:Parameters parameters = {};
    if concepts is r4:CodeSystemConcept {
        parameters = {
            'parameter: [
                {name: "name", valueString: concepts.code},
                {name: "display", valueString: concepts.display}
            ]
        };

        if concepts.definition is string {
            (<international401:ParametersParameter[]>parameters.'parameter).push({name: "definition", valueString: concepts.definition});
        }

        if concepts.property is r4:CodeSystemConceptProperty[] {
            foreach var item in <r4:CodeSystemConceptProperty[]>concepts.property {
                international401:ParametersParameter result = codeSystemConceptPropertyToParameter(item);
                (<international401:ParametersParameter[]>parameters.'parameter).push(result);
            }
        }

        if concepts.designation is r4:CodeSystemConceptDesignation[] {
            foreach var item in <r4:CodeSystemConceptDesignation[]>concepts.designation {
                international401:ParametersParameter result = designationToParameter(item);
                (<international401:ParametersParameter[]>parameters.'parameter).push(result);
            }
        }
    } else {
        international401:ParametersParameter[] p = [];
        foreach r4:CodeSystemConcept item in concepts {
            p.push({name: "name", valueString: item.code},
                    {name: "display", valueString: item.display});

            if item.definition is string {
                p.push({name: "definition", valueString: item.definition});
            }

            if item.property is r4:CodeSystemConceptProperty[] {
                foreach var prop in <r4:CodeSystemConceptProperty[]>item.property {
                    international401:ParametersParameter result = codeSystemConceptPropertyToParameter(prop);
                    p.push(result);
                }
            }

            if item.designation is r4:CodeSystemConceptDesignation[] {
                foreach var desg in <r4:CodeSystemConceptDesignation[]>item.designation {
                    international401:ParametersParameter result = designationToParameter(desg);
                    (<international401:ParametersParameter[]>parameters.'parameter).push(result);
                }
            }
        }
        parameters = {'parameter: p};
    }
    return parameters;
}

isolated function designationToParameter(r4:CodeSystemConceptDesignation designation) returns international401:ParametersParameter {
    international401:ParametersParameter param = {name: "designation"};
    international401:ParametersParameter[] part = [];

    if designation.language is string {
        part.push({name: "language", valueCode: designation.language});
    }

    part.push({name: "value", valueString: designation.value});

    if designation.use is r4:Coding {
        part.push({name: "use", valueCoding: designation.use});
    }
    param.part = part;

    return param;
}

isolated function codeSystemToByte(r4:CodeSystem codeSystem) returns byte[]|r4:FHIRError {
    // remove concepts from the codeSystem object
    // because concepts are stored in separate table in database
    r4:CodeSystem codeSystemWithoutConcepts = codeSystem.clone();
    codeSystemWithoutConcepts.concept = ();

    byte[] byteArray = codeSystemWithoutConcepts.toJsonString().toBytes();

    // check whether the conversion was successful
    r4:CodeSystem|error parsedcs = byteToCodeSystem(byteArray);

    if parsedcs is r4:CodeSystem {
        return byteArray;
    } else {
        return r4:createFHIRError(
                "Error while converting CodeSystem to byte, CodeSystem is not valid, " + parsedcs.message(),
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = parsedcs,
                httpStatusCode = http:STATUS_BAD_REQUEST);
    }
}

isolated function byteToCodeSystem(byte[] byteArray) returns r4:CodeSystem|error {
    string codeSystemJsonString = check 'string:fromBytes(byteArray);
    r4:CodeSystem parsedCodeSystem = check parser:parse(codeSystemJsonString).ensureType();

    return parsedCodeSystem;
}

isolated function conceptToByte(r4:CodeSystemConcept|r4:ValueSetComposeIncludeConcept concept) returns byte[]|r4:FHIRError {
    return concept.toJsonString().toBytes();
}

isolated function byteToConcept(byte[] byteArray) returns r4:CodeSystemConcept|error {
    string conceptJsonString = check 'string:fromBytes(byteArray);
    json conceptJson = check conceptJsonString.fromJsonString();
    r4:CodeSystemConcept parsedConcept = check conceptJson.fromJsonWithType(r4:CodeSystemConcept);

    return parsedConcept;
}

isolated function valueSetToByte(r4:ValueSet valueSet) returns byte[]|r4:FHIRError {
    return valueSet.toJsonString().toBytes();
}

isolated function byteToValueSet(byte[] byteArray) returns r4:ValueSet|error {
    string valueSetJsonString = check 'string:fromBytes(byteArray);
    r4:ValueSet parsedValueSet = check parser:parse(valueSetJsonString).ensureType();

    return parsedValueSet;
}

isolated function streamToStoreCodeSystem(stream<store:CodeSystem, persist:Error?> codeSystemStream) returns store:CodeSystem[]|error {
    store:CodeSystem[] dbCodeSystems = check from store:CodeSystem codeSystem in codeSystemStream
        select codeSystem;
    return dbCodeSystems;
}

isolated function streamToStoreConcept(stream<store:Concept, persist:Error?> conceptStream) returns store:Concept[]|error {
    store:Concept[] dbConcepts = check from store:Concept concept in conceptStream
        select concept;
    return dbConcepts;
}

isolated function streamToStoreValueSet(stream<store:ValueSet, persist:Error?> valueSetStream) returns store:ValueSet[]|error {
    store:ValueSet[] dbValueSets = check from store:ValueSet valueSet in valueSetStream
        select valueSet;
    return dbValueSets;
}

isolated function streamToStoreValueSetComposeInclude(stream<store:ValueSetComposeInclude, persist:Error?> conceptStream) returns store:ValueSetComposeInclude[]|error {
    store:ValueSetComposeInclude[] dbConcepts = check from store:ValueSetComposeInclude concept in conceptStream
        select concept;
    return dbConcepts;
}

isolated function streamToByteArray(stream<byte[], error?> byteArrayStream) returns byte[]|error {
    return check jsondata:parseStream(byteArrayStream);
}

isolated function streamToBytes(stream<byte[], error?> byteStream) returns byte[]|error {
    byte[] result = [];

    check from byte[] chunk in byteStream
        do {
            result = [...result, ...chunk];
        };

    return result;
}

isolated function parseCodeSystemToR4CodeSystem(ParseCodeSystem customCodeSystem) returns r4:CodeSystem => {
    resourceType: customCodeSystem.resourceType,
    meta: customCodeSystem.meta,
    valueSet: customCodeSystem.valueSet,
    date: customCodeSystem.date,
    purpose: customCodeSystem.purpose,
    description: customCodeSystem.description,
    experimental: customCodeSystem.experimental,
    content: customCodeSystem.content ?: "example",
    status: customCodeSystem.status ?: "unknown",
    title: customCodeSystem.title,
    language: customCodeSystem.language,
    id: customCodeSystem.id,
    hierarchyMeaning: customCodeSystem.hierarchyMeaning,
    extension: customCodeSystem.extension,
    copyright: customCodeSystem.copyright,
    jurisdiction: customCodeSystem.jurisdiction,
    modifierExtension: customCodeSystem.modifierExtension,
    contact: customCodeSystem.contact,
    property: customCodeSystem.property,
    text: customCodeSystem.text,
    caseSensitive: customCodeSystem.caseSensitive,
    identifier: customCodeSystem.identifier,
    publisher: customCodeSystem.publisher,
    implicitRules: customCodeSystem.implicitRules,
    name: customCodeSystem.name,
    compositional: customCodeSystem.compositional,
    supplements: customCodeSystem.supplements,
    url: customCodeSystem.url,
    'version: customCodeSystem.'version,
    count: customCodeSystem.count,
    versionNeeded: customCodeSystem.versionNeeded,
    filter: customCodeSystem.filter,
    contained: customCodeSystem.contained,
    useContext: customCodeSystem.useContext,
    concept: customCodeSystem.concept
};

isolated function parseValueSetToR4ValueSet(ParseValueSet customValueSet) returns r4:ValueSet => {
    resourceType: customValueSet.resourceType,
    meta: customValueSet.meta,
    date: customValueSet.date,
    copyright: customValueSet.copyright,
    extension: customValueSet.extension,
    purpose: customValueSet.purpose,
    jurisdiction: customValueSet.jurisdiction,
    modifierExtension: customValueSet.modifierExtension,
    description: customValueSet.description,
    experimental: customValueSet.experimental,
    language: customValueSet.language,
    title: customValueSet.title,
    contact: customValueSet.contact,
    id: customValueSet.id,
    text: customValueSet.text,
    identifier: customValueSet.identifier,
    'version: customValueSet.'version,
    url: customValueSet.url,
    expansion: customValueSet.expansion,
    contained: customValueSet.contained,
    immutable: customValueSet.immutable,
    compose: customValueSet.compose,
    name: customValueSet.name,
    implicitRules: customValueSet.implicitRules,
    publisher: customValueSet.publisher,
    useContext: customValueSet.useContext,
    status: customValueSet.status ?: "unknown"
};

isolated function extractZipFile(string dirPath, string zipFilePath) returns string|error {
    string extractedFolderPath = dirPath + "/extracted";
    check zip:extract(zipFilePath, extractedFolderPath);

    return extractedFolderPath;
}

isolated function removeDirectory(string dirPath) returns error? {
    check file:remove(dirPath, file:RECURSIVE);
}

isolated function saveCompressedPayload(stream<byte[], error?> payloadStream, string dirPath) returns string|error {
    // TODO: add the logic to create create directory in the init function
    if check file:test(dirPath, file:EXISTS) {
        check removeDirectory(dirPath);
    }
    check file:createDir(dirPath);

    string zipFilePath = dirPath + "/file.zip";
    check io:fileWriteBytes(zipFilePath, check streamToBytes(payloadStream));

    return zipFilePath;
}

isolated function readFiles(string path) returns CodeSystemValueSetJson|error {
    file:MetaData[] readDir = check file:readDir(path);

    CodeSystemValueSetJson jsonArrays = {
        codeSystems: [],
        valueSets: []
    };

    foreach var item in readDir {
        string[] nonEmptyParts = regex:split(item.absPath, "\\\\").filter(s => s != "");
        string lastPart = nonEmptyParts[nonEmptyParts.length() - 1];

        if lastPart.endsWith(".json") && lastPart.startsWith("CodeSystem-") {
            jsonArrays.codeSystems.push(check io:fileReadJson(item.absPath));
        } else if lastPart.endsWith(".json") && lastPart.startsWith("ValueSet-") {
            jsonArrays.valueSets.push(check io:fileReadJson(item.absPath));
        }
    }

    return jsonArrays;
}
