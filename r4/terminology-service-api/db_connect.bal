import terminology_service_api.store;

import ballerina/http;
import ballerina/persist;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.terminology;

final store:Client sClient = check new ();

public isolated class TerminologySource {
    *terminology:Terminology;

    public isolated function addCodeSystem(r4:CodeSystem codeSystem) returns r4:FHIRError? {
        // check if the code system already exists
        stream<record {|string id;|}, persist:Error?> dbCodeSystems = sClient->/codesystems();

        persist:Error? unionResult = from var dbCodeSystem in dbCodeSystems
            do {
                if (dbCodeSystem.id == codeSystem.id) {
                    // code system already exists
                    return r4:createFHIRError(
                            "CodeSystem Already Exists",
                            r4:ERROR,
                            r4:INVALID_REQUIRED,
                            cause = error("CodeSystem already exists"),
                            httpStatusCode = http:STATUS_BAD_REQUEST);
                }
            };

        if (unionResult is persist:Error) {
            // error while checking code system existence
            return r4:createFHIRError(
                    "Error while checking CodeSystem existence",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("Error while checking CodeSystem existence"),
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
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
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
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
