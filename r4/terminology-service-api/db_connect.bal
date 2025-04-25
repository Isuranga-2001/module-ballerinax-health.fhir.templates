import terminology_service_api.store;

import ballerina/http;
import ballerina/persist;
import ballerina/sql;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.terminology;

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
            codeSystem: check CodeSystemToByte(codeSystem)
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
                concept: check ConceptToByte(concept),
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
        // TODO: Implement for valuesets
        // check whether the code system exists
        boolean isExist = self.isCodeSystemExist(system, version);

        if !isExist {
            return r4:createFHIRError(
                    "CodeSystem not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching CodeSystem found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        sql:ParameterizedQuery sqlQueryWhereClause = `code = ${code} AND codesystemCodeSystemId = ${system}`;

        stream<store:Concept, persist:Error?> conceptStream = sClient->/concepts(store:Concept, whereClause = sqlQueryWhereClause);
        store:Concept[]|error dbConcept = StreamToStoreConcept(conceptStream);

        if dbConcept is error {
            return r4:createFHIRError(
                    "Error while searching for Concept, " + dbConcept.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = dbConcept,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        if dbConcept.length() == 0 {
            // concept not found
            return r4:createFHIRError(
                    "Concept not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching Concept found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        r4:CodeSystemConcept|error codeSystemConcept = ByteToConcept(dbConcept[0].concept);
        
        if codeSystemConcept is error {
            return r4:createFHIRError(
                    "Error while parsing Concept, " + codeSystemConcept.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = codeSystemConcept,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        return {
            url: system,
            concept: codeSystemConcept
        };
    }

    public isolated function findValueSet(r4:uri? system, string? id, string? version) returns r4:ValueSet|r4:FHIRError {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    public isolated function isCodeSystemExist(r4:uri system, string? version) returns boolean {
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
        sql:ParameterizedQuery[] whereFragments = [];

        foreach var [paramName, paramList] in params.entries() {
            if terminology:CODESYSTEMS_SEARCH_PARAMS.hasKey(paramName) {
                foreach var param in paramList {
                    if whereFragments.length() > 0 {
                        // Add explicit AND between conditions
                        whereFragments.push(` AND `);
                    }
                    match terminology:CODESYSTEMS_SEARCH_PARAMS.get(paramName) {
                        "id" => {
                            whereFragments.push(`id=${param.value}`);
                        }
                        "url" => {
                            whereFragments.push(`url=${param.value}`);
                        }
                        "system" => {
                            whereFragments.push(`url=${param.value}`);
                        }
                        "version" => {
                            whereFragments.push(`version=${param.value}`);
                        }
                        "name" => {
                            whereFragments.push(`name=${param.value}`);
                        }
                        "title" => {
                            whereFragments.push(`title=${param.value}`);
                        }
                        "status" => {
                            whereFragments.push(`status=${param.value}`);
                        }
                        "publisher" => {
                            whereFragments.push(`publisher=${param.value}`);
                        }
                    }
                }
            }
        }

        // Combine all fragments (if any) into a full where clause
        sql:ParameterizedQuery whereClause = whereFragments.length() > 0
            ? sql:queryConcat(...whereFragments)
            : ``;
        
        stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = whereClause);
        store:CodeSystem[]|error dbCodeSystems = StreamToStoreCodeSystem(codeSystemStream);

        if dbCodeSystems is error {
            return r4:createFHIRError(
                    dbCodeSystems.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = dbCodeSystems,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        r4:CodeSystem[] codeSystemArray = [];
        foreach store:CodeSystem dbCodeSystem in dbCodeSystems {
            r4:CodeSystem|error parsedCodeSystem = ByteToCodeSystem(dbCodeSystem.codeSystem);
            if parsedCodeSystem is error {
                // Skip this CodeSystem if parsing fails
                continue;
            }
            codeSystemArray.push(parsedCodeSystem);
        }

        return codeSystemArray;
    }

    public isolated function searchValueSet(map<r4:RequestSearchParameter[]> params, int? offset, int? count) returns r4:ValueSet[]|r4:FHIRError {
        return [];
    }
}

isolated function StreamToStoreCodeSystem(stream<store:CodeSystem, persist:Error?> codeSystemStream) returns store:CodeSystem[]|error {
    store:CodeSystem[] dbCodeSystems = check from store:CodeSystem codeSystem in codeSystemStream select codeSystem;
    return dbCodeSystems;
}

isolated function StreamToStoreConcept(stream<store:Concept, persist:Error?> conceptStream) returns store:Concept[]|error {
    store:Concept[] dbConcepts = check from store:Concept concept in conceptStream select concept;
    return dbConcepts;
}

isolated function getAllCodeSystems() returns r4:CodeSystem[]|error {
    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems();
    store:CodeSystem[] dbCodeSystems = check from var codeSystem in codeSystemStream select codeSystem;

    r4:CodeSystem[] codeSystemArray = [];

    foreach store:CodeSystem dbCodeSystem in dbCodeSystems {
        r4:CodeSystem|error parsedCodeSystem = ByteToCodeSystem(dbCodeSystem.codeSystem);
        if parsedCodeSystem is error {
            // skip this code system if parsing fails
            continue;
        }

        codeSystemArray.push(parsedCodeSystem);
    }

    return codeSystemArray;
}

isolated function getCodeSystemByID(string id, string? version = ()) returns r4:CodeSystem|boolean|r4:FHIRError|persist:Error|error {
    sql:ParameterizedQuery sqlQueryWhereClause = version is ()
        ? `id = ${id} ORDER BY version DESC LIMIT 1`
        : `id = ${id} AND version = ${version}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = sqlQueryWhereClause);
    store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream select codeSystem;

    if codeSystems.length() == 0 {
        return true;
    }

    return ByteToCodeSystem(codeSystems[0].codeSystem);
}

isolated function getCodeSystemByURL(string system, string? version = ()) returns r4:CodeSystem|boolean|r4:FHIRError|persist:Error|error {
    sql:ParameterizedQuery sqlQueryWhereClause = version is ()
        ? `url = ${system} ORDER BY version DESC LIMIT 1`
        : `url = ${system} AND version = ${version}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = sqlQueryWhereClause);
    store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream select codeSystem;

    if codeSystems.length() == 0 {
        return true;
    }

    return ByteToCodeSystem(codeSystems[0].codeSystem);
}
