import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.parser;
import ballerina/http;

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

isolated function extractConcepts(r4:CodeSystem codeSystem) returns r4:CodeSystemConcept[] {
    r4:CodeSystemConcept[] concepts = [];
    if codeSystem.concept !is () {
        foreach var concept in <r4:CodeSystemConcept[]>codeSystem.concept {
            concepts = extractConceptsRecursive(concept, concepts);
        }
    }
    return concepts;
}

isolated function extractConceptsRecursive(r4:CodeSystemConcept var_concept, r4:CodeSystemConcept[] acc) returns r4:CodeSystemConcept[] {
    r4:CodeSystemConcept[] updatedAcc = acc.clone();
    updatedAcc.push(var_concept);
    if var_concept.concept !is () {
        foreach var subConcept in <r4:CodeSystemConcept[]>var_concept.concept {
            updatedAcc = extractConceptsRecursive(subConcept, updatedAcc);
        }
    }
    return updatedAcc;
}

isolated function CodeSystemToByte(r4:CodeSystem codeSystem) returns byte[]|r4:FHIRError {
    // remove concepts from the codeSystem object
    // because concepts are stored in separate table in database
    r4:CodeSystem codeSystemWithoutConcepts = codeSystem.clone();
    codeSystemWithoutConcepts.concept = ();

    byte[] byteArray = codeSystemWithoutConcepts.toJsonString().toBytes();

    // check whether the conversion was successful
    r4:CodeSystem|error parsedcs = ByteToCodeSystem(byteArray);

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

isolated function ByteToCodeSystem(byte[] byteArray) returns r4:CodeSystem|error {
    string codeSystemJsonString = check 'string:fromBytes(byteArray);
    r4:CodeSystem parsedCodeSystem = check parser:parse(codeSystemJsonString).ensureType();

    return parsedCodeSystem;
}

isolated function ConceptToByte(r4:CodeSystemConcept concept) returns byte[]|r4:FHIRError {
    byte[] byteArray = concept.toJsonString().toBytes();
    return byteArray;
}

isolated function ByteToConcept(byte[] byteArray) returns r4:CodeSystemConcept|error {
    string conceptJsonString = check 'string:fromBytes(byteArray);
    json conceptJson = check conceptJsonString.fromJsonString();
    r4:CodeSystemConcept parsedConcept = check conceptJson.fromJsonWithType(r4:CodeSystemConcept);

    return parsedConcept;
}

