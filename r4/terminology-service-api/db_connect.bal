import terminology_service_api.store;

import ballerina/http;
import ballerina/persist;
// import ballerina/regex;
import ballerina/sql;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.parser;
import ballerinax/health.fhir.r4.terminology;
import ballerina/io;

final store:Client sClient = check new ();

public isolated class TerminologySource {
    *terminology:Terminology;

    public isolated function addCodeSystem(r4:CodeSystem codeSystem) returns r4:FHIRError? {
        if codeSystem.id !is () {
            r4:CodeSystem|boolean|r4:FHIRError|error dbCodeSystem = getCodeSystemByID(<string>codeSystem.id, codeSystem.version);

            if dbCodeSystem is r4:FHIRError {
                return dbCodeSystem;
            } else if dbCodeSystem is error {
                return r4:createFHIRError(
                        "Error while checking CodeSystem existence",
                        r4:ERROR,
                        r4:INVALID_REQUIRED,
                        cause = dbCodeSystem,
                        httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
            } else if dbCodeSystem is boolean && dbCodeSystem == false {
                return r4:createFHIRError(
                        "CodeSystem Already Exists",
                        r4:ERROR,
                        r4:INVALID_REQUIRED,
                        cause = error("CodeSystem already exists"),
                        httpStatusCode = http:STATUS_BAD_REQUEST);
            }
        }

        // add the code system to the database
        store:CodeSystemInsert dbCodeSystemInsert = {
            id: codeSystem.id ?: "",
            url: codeSystem.url ?: "",
            version: codeSystem.version ?: "",
            name: codeSystem.name ?: "",
            title: codeSystem.title ?: "",
            status: codeSystem.status,
            date: codeSystem.date ?: "",
            publisher: codeSystem.publisher ?: "",
            codeSystem: codeSystem.toJson().toString().toBytes()
        };

        int[]|persist:Error response = sClient->/codesystems.post([dbCodeSystemInsert]);
        if (response is persist:Error) {
            // error while adding code system to the database
            return r4:createFHIRError(
                    "Error while adding CodeSystem",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("Error while adding CodeSystem"),
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        // extract the concepts from the codesystem and add them to the database
        r4:CodeSystemConcept[] codeSystemConcepts = extractConcepts(codeSystem);

        store:ConceptInsert[] conceptInsertList = [];
        foreach r4:CodeSystemConcept concept in codeSystemConcepts {
            store:ConceptInsert dbConceptInsert = {
                code: concept.code,
                display: concept.display ?: "",
                definition: concept.definition ?: "",
                concept: concept.toString().toBytes(),
                codesystemCodeSystemId: response[0]
            };
            conceptInsertList.push(dbConceptInsert);
        }

        int[]|persist:Error conceptresponse = sClient->/concepts.post(conceptInsertList);
        if (conceptresponse is persist:Error) {
            // error while adding code system to the database
            store:CodeSystem|persist:Error responseDelete = sClient->/codesystems/[response[0]].delete();
            if (responseDelete is persist:Error) {
                // error while deleting code system from the database
                return r4:createFHIRError(
                        "Error while deleting CodeSystem, due to error while adding concepts",
                        r4:ERROR,
                        r4:INVALID_REQUIRED,
                        cause = responseDelete,
                        httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
            }

            return r4:createFHIRError(
                    "Error while adding CodeSystem: " + conceptresponse.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = conceptresponse,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        return ();
    }

    public isolated function addValueSet(r4:ValueSet valueSet) returns r4:FHIRError? {
        // check if the value set already exists
        stream<record {|string id;|}, persist:Error?> dbValueSets = sClient->/valuesets();

        persist:Error? unionResult = from var dbValueSet in dbValueSets
            do {
                if (dbValueSet.id == valueSet.id) {
                    // value set already exists
                    return r4:createFHIRError(
                            "ValueSet Already Exists",
                            r4:ERROR,
                            r4:INVALID_REQUIRED,
                            cause = error("ValueSet already exists"),
                            httpStatusCode = http:STATUS_BAD_REQUEST);
                }
            };

        if (unionResult is persist:Error) {
            // error while checking value set existence
            return r4:createFHIRError(
                    "Error while checking ValueSet existence",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("Error while checking ValueSet existence"),
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        // add the value set to the database
        store:ValueSetInsert dbValueSetInsert = {
            id: valueSet.id ?: "",
            url: valueSet.url ?: "",
            version: valueSet.version ?: "",
            name: valueSet.name ?: "",
            title: valueSet.title ?: "",
            status: valueSet.status,
            date: valueSet.date ?: "",
            publisher: valueSet.publisher ?: "",
            valueSet: valueSet.toString().toBytes()
        };

        int[]|persist:Error response = sClient->/valuesets.post([dbValueSetInsert]);
        if (response is persist:Error) {
            // error while adding value set to the database
            return r4:createFHIRError(
                    "Error while adding ValueSet",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("Error while adding ValueSet"),
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
        return ();
    }

    public isolated function findCodeSystem(r4:uri? system, string? id, string? version) returns r4:CodeSystem|r4:FHIRError {
        r4:CodeSystem|boolean|r4:FHIRError|error dbCodeSystem;

        if id != () {
            dbCodeSystem = getCodeSystemByID(id, version);
        } else if system != () {
            dbCodeSystem = getCodeSystemByURL(system, version);
        } else {
            return r4:createFHIRError(
                    "Id or URL for the codesystem is required to find CodeSystem",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching CodeSystem found"),
                    httpStatusCode = http:STATUS_BAD_REQUEST);
        }

        if dbCodeSystem is r4:FHIRError {
            return dbCodeSystem;
        }

        if dbCodeSystem is error {
            return r4:createFHIRError(
                    "Cannot find CodeSystem, " + dbCodeSystem.message(),
                    r4:ERROR,
                    r4:PROCESSING_NOT_FOUND,
                    cause = dbCodeSystem,
                    httpStatusCode = http:STATUS_NOT_FOUND
                );
        }

        if dbCodeSystem is boolean {
            return r4:createFHIRError(
                    "CodeSystem not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching CodeSystem found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        return dbCodeSystem;
    }

    public isolated function findConcept(r4:uri system, r4:code code, string? version) returns terminology:CodeConceptDetails|r4:FHIRError {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    public isolated function findValueSet(r4:uri? system, string? id, string? version) returns r4:ValueSet|r4:FHIRError {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    public isolated function isCodeSystemExist(r4:uri system, string version) returns boolean {
        r4:CodeSystem|boolean|r4:FHIRError|persist:Error|error result = getCodeSystemByURL(system, version);
        
        if result is r4:CodeSystem {
            return true;
        }

        return false;
    }

    public isolated function isValueSetExist(r4:uri system, string version) returns boolean {
        // stream<record {|string url; string version;|}, persist:Error?> dbValueSets = sClient->/valuesets();

        // do {
        //     check from var dbValueSet in dbValueSets do {
        //         if (dbValueSet.url == system && dbValueSet.version == version) {
        //             return true;
        //         }
        //     };
        // } on fail {
        //     return false;
        // }

        return false;
    }

    public isolated function searchCodeSystem(map<r4:RequestSearchParameter[]> params, int? offset, int? count) returns r4:CodeSystem[]|r4:FHIRError {
        r4:CodeSystem[]|error getAllResult = getAllCodeSystems();

        if getAllResult is error {
            return r4:createFHIRError(
                    "Error while getting CodeSystems",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = getAllResult,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        r4:CodeSystem[] codeSystemArray = getAllResult;
        
        foreach var searchParam in params.keys() {
            r4:RequestSearchParameter[] searchParamValues = params.cloneReadOnly()[searchParam] ?: [];
            r4:CodeSystem[] filteredList = [];
            if searchParamValues.length() != 0 {
                foreach var queriedValue in searchParamValues {
                    r4:CodeSystem[] result = from r4:CodeSystem entry in codeSystemArray
                        where entry[terminology:CODESYSTEMS_SEARCH_PARAMS.get(searchParam)] == queriedValue.value
                        select entry;
                    filteredList.push(...result);
                }
                codeSystemArray = filteredList;
            }
        }

        int total = codeSystemArray.length();
        int validatedCount = count ?: terminology:TERMINOLOGY_SEARCH_DEFAULT_COUNT;

        if total >= offset + validatedCount {
            return codeSystemArray.slice(offset ?: 0, (offset ?: 0) + validatedCount).clone();
        } else if total >= offset {
            return codeSystemArray.slice(offset ?: 0).clone();
        } else {
            return [];
        }
    }

    public isolated function searchValueSet(map<r4:RequestSearchParameter[]> params, int? offset, int? count) returns r4:ValueSet[]|r4:FHIRError {
        return [];
    }
}

isolated function createFHIRError(string s, string s1, string s2, any cause, int httpStatusCode) returns r4:CodeSystem[]|r4:FHIRError {
    return [];
}

isolated function getAllCodeSystems() returns r4:CodeSystem[]|error {
    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems();
    store:CodeSystem[] dbCodeSystems = check from var codeSystem in codeSystemStream select codeSystem;
    
    io:println("CodeSystem count: ", dbCodeSystems.count());

    r4:CodeSystem[] codeSystemArray = [];

    foreach store:CodeSystem dbCodeSystem in dbCodeSystems {
        io:println("CodeSystem Added: ", dbCodeSystem.id, " ", dbCodeSystem.version);
        string codeSystemJsonString = check 'string:fromBytes(dbCodeSystem.codeSystem);

        r4:CodeSystem|error parsedCodeSystem = parser:parse(codeSystemJsonString.toJson()).ensureType();
        if parsedCodeSystem is error {
            // skip this code system if parsing fails
            continue;
        }

        codeSystemArray.push(parsedCodeSystem);
    }

    io:println("CodeSystemArray count: ", codeSystemArray.length());

    return codeSystemArray;
}

isolated function getCodeSystemByID(string id, string? version = ()) returns r4:CodeSystem|boolean|r4:FHIRError|persist:Error|error {
    sql:ParameterizedQuery sqlQuery = version is ()
        ? `SELECT * FROM codesystems WHERE id = ${id} ORDER BY CAST(version AS DECIMAL) DESC LIMIT 1`
        : `SELECT * FROM codesystems WHERE id = ${id} AND version = ${version}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->queryNativeSQL(sqlQuery, store:CodeSystem);
    store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream select codeSystem;

    if codeSystems.length() == 0 {
        return true;
    }

    string codeSystemJsonString = check 'string:fromBytes(codeSystems[0].codeSystem);
    r4:CodeSystem parsedCodeSystem = check parser:parse(codeSystemJsonString.toJson()).ensureType();

    return parsedCodeSystem;
}

isolated function getCodeSystemByURL(string system, string? version = ()) returns r4:CodeSystem|boolean|r4:FHIRError|persist:Error|error {
    sql:ParameterizedQuery sqlQuery = version is ()
        ? `SELECT * FROM codesystems WHERE url = ${system} ORDER BY CAST(version AS DECIMAL) DESC LIMIT 1`
        : `SELECT * FROM codesystems WHERE url = ${system} AND version = ${version}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->queryNativeSQL(sqlQuery, store:CodeSystem);
    store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream select codeSystem;

    if codeSystems.length() == 0 {
        return true;
    }

    string codeSystemJsonString = check 'string:fromBytes(codeSystems[0].codeSystem);
    r4:CodeSystem parsedCodeSystem = check parser:parse(codeSystemJsonString.toJson()).ensureType();

    return parsedCodeSystem;
}
