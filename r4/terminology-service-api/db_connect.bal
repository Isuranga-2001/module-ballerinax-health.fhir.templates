import terminology_service_api.store;

import ballerina/http;
import ballerina/persist;
import ballerina/sql;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.parser;
import ballerinax/health.fhir.r4.terminology;
import ballerina/lang.regexp;

final store:Client sClient = check new ();

public isolated class TerminologySource {
    *terminology:Terminology;

    public isolated function addCodeSystem(r4:CodeSystem codeSystem) returns r4:FHIRError? {
        if codeSystem.id !is () {
            r4:CodeSystem|r4:FHIRError|error dbCodeSystem = getCodeSystemByID(<string>codeSystem.id, codeSystem.version);

            if dbCodeSystem is r4:FHIRError {
                // error while checking code system existence
                return dbCodeSystem;
            }

            if dbCodeSystem is error {
                // error while checking code system existence
                return r4:createFHIRError(
                        "Error while checking CodeSystem existence",
                        r4:ERROR,
                        r4:INVALID_REQUIRED,
                        cause = dbCodeSystem,
                        httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
            } 
            
            if dbCodeSystem.status != "unknown" {
                // code system already exists
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
            codeSystem: codeSystem.toString().toBytes()
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
                display: <string>concept.display,
                definition: <string>concept.definition,
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
        if id != () {
            r4:CodeSystem|r4:FHIRError|error dbCodeSystem;
            if version != () {
                dbCodeSystem = getCodeSystemByID(id, version);
            } else {
                dbCodeSystem = getCodeSystemByID(id);
            }

            if dbCodeSystem is r4:FHIRError {
                return dbCodeSystem;
            }

            if dbCodeSystem is error {
                return r4:createFHIRError(
                        string `Unknown CodeSystem Id: '${id}'`,
                        r4:ERROR,
                        r4:PROCESSING_NOT_FOUND,
                        cause = dbCodeSystem,
                        httpStatusCode = http:STATUS_NOT_FOUND
                    );
            }
            
            return dbCodeSystem;
        }

        stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems.get();

        map<r4:CodeSystem> codeSystems = check from var codeSystem in codeSystemStream
            do {
                if (codeSystem.codeSystem is r4:CodeSystem) {
                    string codeSystemId = <string>codeSystem.codeSystem.id;
                    string codeSystemVersion = <string>codeSystem.codeSystem.version;
                    string codeSystemKey = codeSystemId + "|" + codeSystemVersion;
                    r4:CodeSystem parsedCodeSystem = check parser:parse(codeSystem.codeSystem.toJson()).ensureType();
                    return {codeSystemKey: parsedCodeSystem};
                }
            } ?: error("");



        boolean isIdExistInRegistry = false;
        if version is string && system != () {
            foreach var item in codeSystems.keys() {
                if regexp:isFullMatch(re `${system}\|${version}$`, item) && codeSystems[item] is r4:CodeSystem {
                    return <r4:CodeSystem>codeSystems[item].clone();
                } else if regexp:isFullMatch(re `${system}\|.*`, item) {
                    isIdExistInRegistry = true;
                }
            }

            if isIdExistInRegistry {
                return r4:createFHIRError(
                            string `Unknown version: '${version}',`,
                        r4:ERROR,
                        r4:PROCESSING_NOT_FOUND,
                        diagnostic = string `: there is a CodeSystem in the registry with Id: '${system.toString()}' but cannot find version: '${version}' of it.`,
                        httpStatusCode = http:STATUS_NOT_FOUND
                        );
            }
        } else if system != () {
            r4:CodeSystem codeSystem = {content: "example", status: "unknown"};
            string latestVersion = terminology:DEFAULT_VERSION;
            foreach var item in codeSystems.keys() {
                if regexp:isFullMatch(re `${system}\|.*`, item)
                && codeSystems[item] is r4:CodeSystem
                && (<r4:CodeSystem>codeSystems[item]).version > latestVersion {
                    codeSystem = <r4:CodeSystem>codeSystems[item];
                    latestVersion = codeSystem.version ?: terminology:DEFAULT_VERSION;
                    isIdExistInRegistry = true;
                }
            }

            if isIdExistInRegistry {
                return codeSystem.clone();
            } else {
                return r4:createFHIRError(
                            string `Unknown CodeSystem: '${system.toBalString()}'`,
                        r4:ERROR,
                        r4:PROCESSING_NOT_FOUND,
                        httpStatusCode = http:STATUS_NOT_FOUND
                        );
            }
        }
        return r4:createFHIRError(
                string `Unknown CodeSystem: '${system.toBalString()}'`,
                r4:ERROR,
                r4:PROCESSING_NOT_FOUND,
                httpStatusCode = http:STATUS_NOT_FOUND
            );
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
        // stream<record {|string url; string version;|}, persist:Error?> dbCodeSystems = sClient->/codesystems();

        // do { 
        //     check from var dbCodeSystem in dbCodeSystems do {
        //         if (dbCodeSystem.url == system && dbCodeSystem.version == version) {
        //             return true;
        //         }
        //     };
        // } on fail {
        //     return false;
        // }

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
        return [];
    }

    public isolated function searchValueSet(map<r4:RequestSearchParameter[]> params, int? offset, int? count) returns r4:ValueSet[]|r4:FHIRError {
        return [];
    }
}

isolated function getCodeSystemByID(string id, string? version = ()) returns r4:CodeSystem|r4:FHIRError|persist:Error|error {
    sql:ParameterizedQuery sqlQuery = `SELECT * FROM codesystems WHERE id = ${id}${version is () ? "" : string ` AND version = ${version}`}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->queryNativeSQL(sqlQuery, store:CodeSystem);
    store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream select codeSystem;

    r4:CodeSystem parsedCodeSystem = check parser:parse(codeSystems[0].codeSystem.toJson()).ensureType();
    return parsedCodeSystem;
}
