import terminology_service_api.store;

import ballerina/http;
import ballerina/log;
import ballerina/persist;
import ballerina/sql;
import ballerina/regex;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.terminology;

final store:Client sClient = check initializeClient();

function initializeClient() returns store:Client|error {
    return new ();
}

public isolated class TerminologySource {
    *terminology:Terminology;

    public isolated function addCodeSystem(r4:CodeSystem codeSystem) returns r4:FHIRError? {
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
            codeSystem: check codeSystemToByte(codeSystem)
        };

        int[]|persist:Error response = sClient->/codesystems.post([dbCodeSystemInsert]);
        if (response is persist:Error) {
            // error while adding code system to the database
            return r4:createFHIRError(
                    "Error while adding CodeSystem, " + response.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("Error while adding CodeSystem"),
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        // extract the concepts from the codesystem and add them to the database
        extractConceptsFromCodeSystem(codeSystem, response[0]);
    }

    public isolated function addValueSet(r4:ValueSet valueSet) returns r4:FHIRError? {
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
            valueSet: check valueSetToByte(valueSet)
        };

        int[]|persist:Error response = sClient->/valuesets.post([dbValueSetInsert]);
        if (response is persist:Error) {
            // error while adding value set to the database
            return r4:createFHIRError(
                    "Error while adding ValueSet, " + response.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("Error while adding ValueSet"),
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        // extract the concepts from the valueset and add them to the database
        extractConceptsFromValueSet(valueSet, response[0]);
    }

    public isolated function findCodeSystem(r4:uri? system, string? id, string? version = ()) returns r4:CodeSystem|r4:FHIRError {
        r4:CodeSystem|r4:FHIRError|error dbCodeSystem;

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
                    dbCodeSystem.message(),
                    r4:ERROR,
                    r4:PROCESSING_NOT_FOUND,
                    cause = dbCodeSystem,
                    httpStatusCode = http:STATUS_NOT_FOUND
                );
        }

        return dbCodeSystem;
    }

    public isolated function findConcept(r4:uri system, r4:code code, string? version) returns terminology:CodeConceptDetails|r4:FHIRError {
        // find the concept in the valueset table
        terminology:CodeConceptDetails|r4:FHIRError valuesetConceptDetails = findConceptInValueSet(system, code, version);
        if valuesetConceptDetails !is r4:FHIRError {
            return valuesetConceptDetails;
        }
        
        // find the concept in the codesystem table
        terminology:CodeConceptDetails|r4:FHIRError conceptDetails = findConceptInCodeSystem(system, code, version);
        if conceptDetails !is r4:FHIRError {
            return conceptDetails;
        }

        // concept not found in both tables
        return r4:createFHIRError(
                "Concept not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching Concept found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    public isolated function findValueSet(r4:uri? system, string? id, string? version) returns r4:ValueSet|r4:FHIRError {
        r4:ValueSet|r4:FHIRError|error dbValueSet;

        if id != () {
            dbValueSet = getValueSetByID(id, version);
        } else if system != () {
            dbValueSet = getValueSetByURL(system, version);
        } else {
            return r4:createFHIRError(
                    "Id or URL for the valueset is required to find ValueSet",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching ValueSet found"),
                    httpStatusCode = http:STATUS_BAD_REQUEST);
        }

        if dbValueSet is r4:FHIRError {
            return dbValueSet;
        }

        if dbValueSet is error {
            return r4:createFHIRError(
                    "Cannot find ValueSet, " + dbValueSet.message(),
                    r4:ERROR,
                    r4:PROCESSING_NOT_FOUND,
                    cause = dbValueSet,
                    httpStatusCode = http:STATUS_NOT_FOUND
                );
        }

        return dbValueSet;
    }

    public isolated function isCodeSystemExist(r4:uri system, string? version) returns boolean {
        r4:CodeSystem|r4:FHIRError|persist:Error|error result = getCodeSystemByURL(system, version);
        if result is r4:CodeSystem {
            return true;
        }
        return false;
    }

    public isolated function isValueSetExist(r4:uri system, string version) returns boolean {
        r4:ValueSet|r4:FHIRError|persist:Error|error result = getValueSetByURL(system, version);
        if result is r4:ValueSet {
            return true;
        }
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
                            whereFragments.push(`"id"=${param.value}`);
                        }
                        "url" => {
                            whereFragments.push(`"url"=${param.value}`);
                        }
                        "system" => {
                            whereFragments.push(`"url"=${param.value}`);
                        }
                        "version" => {
                            whereFragments.push(`"version"=${param.value}`);
                        }
                        "name" => {
                            whereFragments.push(`"name" LIKE ${param.value}`);
                        }
                        "title" => {
                            whereFragments.push(`"title" LIKE ${param.value}`);
                        }
                        "status" => {
                            whereFragments.push(`"status"=${param.value}`);
                        }
                        "publisher" => {
                            whereFragments.push(`"publisher"=${param.value}`);
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
        store:CodeSystem[]|error dbCodeSystems = streamToStoreCodeSystem(codeSystemStream);

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
            r4:CodeSystem|error parsedCodeSystem = byteToCodeSystem(dbCodeSystem.codeSystem);
            if parsedCodeSystem is error {
                // Skip this CodeSystem if parsing fails
                continue;
            }
            codeSystemArray.push(parsedCodeSystem);
        }

        return codeSystemArray;
    }

    public isolated function searchValueSet(map<r4:RequestSearchParameter[]> params, int? offset, int? count) returns r4:ValueSet[]|r4:FHIRError {
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
                            whereFragments.push(`"id"=${param.value}`);
                        }
                        "url" => {
                            whereFragments.push(`"url"=${param.value}`);
                        }
                        "system" => {
                            whereFragments.push(`"url"=${param.value}`);
                        }
                        "version" => {
                            whereFragments.push(`"version"=${param.value}`);
                        }
                        "name" => {
                            whereFragments.push(`"name" LIKE ${param.value}`);
                        }
                        "title" => {
                            whereFragments.push(`"title" LIKE ${param.value}`);
                        }
                        "status" => {
                            whereFragments.push(`"status"=${param.value}`);
                        }
                        "publisher" => {
                            whereFragments.push(`"publisher"=${param.value}`);
                        }
                    }
                }
            }
        }

        // Combine all fragments (if any) into a full where clause
        sql:ParameterizedQuery whereClause = whereFragments.length() > 0
            ? sql:queryConcat(...whereFragments)
            : ``;

        stream<store:ValueSet, persist:Error?> valueSetStream = sClient->/valuesets(store:ValueSet, whereClause = whereClause);
        store:ValueSet[]|error dbValueSets = streamToStoreValueSet(valueSetStream);

        if dbValueSets is error {
            return r4:createFHIRError(
                    dbValueSets.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = dbValueSets,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        r4:ValueSet[] valueSetArray = [];
        foreach store:ValueSet dbValueSet in dbValueSets {
            r4:ValueSet|error parsedValueSet = byteToValueSet(dbValueSet.valueSet);
            if parsedValueSet is error {
                // Skip this ValueSet if parsing fails
                continue;
            }
            valueSetArray.push(parsedValueSet);
        }

        return valueSetArray;
    }
}

isolated function findConceptInValueSet(r4:uri system, r4:code code, string? version) returns terminology:CodeConceptDetails|r4:FHIRError {
    // check whether the value set exists
    var valueset = getStoreValueSetByURL(system, version);

    if valueset !is store:ValueSet {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }
    
    // checks for valueset concepts
    sql:ParameterizedQuery sqlQuery = `SELECT c.*
        FROM "concepts" c
            JOIN "valueset_compose_include_concepts" vcic 
                ON c."conceptId" = vcic."conceptConceptId"
            JOIN "valueset_compose_includes" vci 
                ON vcic."valuesetcomposeValueSetComposeIncludeId" = vci."valueSetComposeIncludeId"
            JOIN "valuesets" vs 
                ON vci."valuesetValueSetId" = vs."valueSetId"
        WHERE vs."valueSetId" = ${valueset.valueSetId} AND c."code" = ${code};`;

    store:Concept|r4:FHIRError dbConcept = getStoreConcept(sqlQuery);
    if dbConcept !is r4:FHIRError {
        r4:CodeSystemConcept|error valueSetConcept = byteToConcept(dbConcept.concept);

        if valueSetConcept !is error {
            return {
                url: system,
                concept: valueSetConcept
            };
        }
    }

    // checks for code systems
    sqlQuery = `SELECT c.*
        FROM "concepts" c
            JOIN "codesystems" cs 
                ON c."codesystemCodeSystemId" = cs."codeSystemId"
            JOIN "valueset_compose_includes" vci 
                ON cs."codeSystemId" = vci."codeSystemId"
            JOIN "valuesets" vs 
                ON vci."valuesetValueSetId" = vs."valueSetId"
        WHERE vs."valueSetId" = ${valueset.valueSetId} AND c."code" = ${code}`;

    dbConcept = getStoreConcept(sqlQuery);
    if dbConcept !is r4:FHIRError {
        r4:CodeSystemConcept|error valueSetConcept = byteToConcept(dbConcept.concept);

        if valueSetConcept !is error {
            return {
                url: system,
                concept: valueSetConcept
            };
        }
    }

    // checks for nested valueset references
    sqlQuery = `SELECT vs_included.*
        FROM "valuesets" vs_parent
            JOIN "valueset_compose_includes" vci 
                ON vs_parent."valueSetId" = vci."valuesetValueSetId"
            JOIN "valueset_compose_include_value_sets" vcivs 
                ON vci."valueSetComposeIncludeId" = vcivs."valuesetcomposeValueSetComposeIncludeId"
            JOIN "valuesets" vs_included 
                ON vcivs."valuesetValueSetId" = vs_included."valueSetId"
        WHERE vs_parent."valueSetId" = ${valueset.valueSetId}`;

    stream<store:ValueSet, persist:Error?> valueSetStream = sClient->queryNativeSQL(sqlQuery);
    store:ValueSet[]|error nestedValueSets = streamToStoreValueSet(valueSetStream);

    if nestedValueSets is error {
        return r4:createFHIRError(
                "Error while searching for Concept, " + nestedValueSets.message(),
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = nestedValueSets,
                httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
    }

    if nestedValueSets.length() > 0 {
        foreach store:ValueSet nestedValueSet in nestedValueSets {
            var result =  findConceptInValueSet(nestedValueSet.url, code, nestedValueSet.version);
            if result !is r4:FHIRError {
                return result;
            }
        }
    }

    // not found in the value set
    return r4:createFHIRError(
            "Concept not found",
            r4:ERROR,
            r4:INVALID_REQUIRED,
            cause = error("No matching Concept found"),
            httpStatusCode = http:STATUS_NOT_FOUND);
}

isolated function findConceptInCodeSystem(r4:uri system, r4:code code, string? version) returns terminology:CodeConceptDetails|r4:FHIRError {
    // check whether the code system exists
    var codeSystem = getStoreCodeSystemByURL(system, version);

    if codeSystem !is store:CodeSystem {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    var dbConcept = getStoreConceptByCode(codeSystem.codeSystemId, code); 
    if dbConcept is error {
        return dbConcept;
    }       

    r4:CodeSystemConcept|error codeSystemConcept = byteToConcept(dbConcept.concept);

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

// functions

isolated function getAllCodeSystems() returns r4:CodeSystem[]|error {
    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems();
    store:CodeSystem[] dbCodeSystems = check streamToStoreCodeSystem(codeSystemStream);

    r4:CodeSystem[] codeSystemArray = [];

    foreach store:CodeSystem dbCodeSystem in dbCodeSystems {
        r4:CodeSystem|error parsedCodeSystem = byteToCodeSystem(dbCodeSystem.codeSystem);
        if parsedCodeSystem is error {
            // skip this code system if parsing fails
            continue;
        }

        codeSystemArray.push(parsedCodeSystem);
    }

    return codeSystemArray;
}

isolated function getCodeSystemByID(string id, string? version = ()) returns r4:CodeSystem|error {
    sql:ParameterizedQuery sqlQueryWhereClause = version is ()
        ? `"id" = ${id} ORDER BY "version" DESC LIMIT 1`
        : `"id" = ${id} AND "version" = ${version}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = sqlQueryWhereClause);
    store:CodeSystem[] codeSystems = check streamToStoreCodeSystem(codeSystemStream);

    if codeSystems.length() == 0 {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    return byteToCodeSystem(codeSystems[0].codeSystem);
}

isolated function getCodeSystemByURL(string system, string? version = ()) returns r4:CodeSystem|error {
    store:CodeSystem storeCodeSystem = check getStoreCodeSystemByURL(system, version);

    return byteToCodeSystem(storeCodeSystem.codeSystem);
}

isolated function getStoreCodeSystemByURL(string system, string? version = ()) returns store:CodeSystem|error {
    sql:ParameterizedQuery sqlQueryWhereClause = version is ()
        ? `"url" = ${system} ORDER BY "version" DESC LIMIT 1`
        : `"url" = ${system} AND "version" = ${version}`;

    stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = sqlQueryWhereClause);
    store:CodeSystem[] codeSystems = check streamToStoreCodeSystem(codeSystemStream);

    if codeSystems.length() == 0 {
        return r4:createFHIRError(
                "CodeSystem not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching CodeSystem found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }
    return codeSystems[0];
}

isolated function getValueSetByID(string id, string? version = ()) returns r4:ValueSet|error {
    sql:ParameterizedQuery sqlQueryWhereClause = version is ()
        ? `"id" = ${id} ORDER BY "version" DESC LIMIT 1`
        : `"id" = ${id} AND "version" = ${version}`;

    stream<store:ValueSet, persist:Error?> valueSetStream = sClient->/valuesets(store:ValueSet, whereClause = sqlQueryWhereClause);
    store:ValueSet[] valueSets = check streamToStoreValueSet(valueSetStream);

    if valueSets.length() == 0 {
        return r4:createFHIRError(
                "ValueSet not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching ValueSet found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }

    // Assuming byteToValueSet is available similar to byteToCodeSystem
    return byteToValueSet(valueSets[0].valueSet);
}

isolated function getValueSetByURL(string system, string? version = ()) returns r4:ValueSet|error {
    store:ValueSet storeValueSet = check getStoreValueSetByURL(system, version);

    return byteToValueSet(storeValueSet.valueSet);
}

isolated function getStoreValueSetByURL(string system, string? version = ()) returns store:ValueSet|error {
    sql:ParameterizedQuery sqlQueryWhereClause = version is ()
        ? `"url" = ${system} ORDER BY "version" DESC LIMIT 1`
        : `"url" = ${system} AND "version" = ${version}`;

    stream<store:ValueSet, persist:Error?> valueSetStream = sClient->/valuesets(store:ValueSet, whereClause = sqlQueryWhereClause);
    store:ValueSet[] valueSets = check streamToStoreValueSet(valueSetStream);

    if valueSets.length() == 0 {
        return r4:createFHIRError(
                "ValueSet not found",
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = error("No matching ValueSet found"),
                httpStatusCode = http:STATUS_NOT_FOUND);
    }
    return valueSets[0];
}

isolated function getStoreConceptByCode(int codeSystemId, r4:code code) returns store:Concept|r4:FHIRError {
    return getStoreConcept(`SELECT * FROM "concepts" WHERE "code" = ${code} AND "codesystemCodeSystemId" = ${codeSystemId}`);
}

isolated function getStoreConcept(sql:ParameterizedQuery sqlQuery) returns store:Concept|r4:FHIRError {
    stream<store:Concept, persist:Error?> conceptStream = sClient->queryNativeSQL(sqlQuery);
    store:Concept[]|error dbConcepts = streamToStoreConcept(conceptStream);

    if dbConcepts is error {
        return r4:createFHIRError(
                "Error while searching for Concept, " + dbConcepts.message(),
                r4:ERROR,
                r4:INVALID_REQUIRED,
                cause = dbConcepts,
                httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
    }

    if dbConcepts.length() > 0 {
        return dbConcepts[0];
    }

    // concept not found
    return r4:createFHIRError(
            "Concept not found",
            r4:ERROR,
            r4:INVALID_REQUIRED,
            cause = error("No matching Concept found"),
            httpStatusCode = http:STATUS_NOT_FOUND);
}

isolated function extractConceptsFromCodeSystem(r4:CodeSystem codeSystem, int codeSystemId) {
    if codeSystem.concept !is () {
        foreach var concept in <r4:CodeSystemConcept[]>codeSystem.concept {
            _ = start extractConceptsFromCodeSystemRecursive(concept.clone(), codeSystemId);
        }
    }
}

isolated function extractConceptsFromCodeSystemRecursive(r4:CodeSystemConcept var_concept, int codeSystemId, int? parentId = ()) {
    int|error result = saveCodeSystemConcept(var_concept, codeSystemId, parentId);
    if result is error {
        log:printError("Error while saving concept: " + result.message());
    }

    if var_concept.concept !is () {
        foreach var subConcept in <r4:CodeSystemConcept[]>var_concept.concept {
            _ = start extractConceptsFromCodeSystemRecursive(subConcept.clone(), codeSystemId, (result is int) ? result : ());
        }
    }
}

isolated function saveCodeSystemConcept(r4:CodeSystemConcept concept, int codeSystemId, int? parentId) returns int|error {
    store:ConceptInsert dbConceptInsert = {
        code: concept.code,
        concept: check conceptToByte(concept),
        codesystemCodeSystemId: codeSystemId,
        parentConceptId: parentId
    };

    int[] id = check sClient->/concepts.post([dbConceptInsert]);
    return id[0];
}

// Extract concepts from a ValueSet and save them recursively
isolated function extractConceptsFromValueSet(r4:ValueSet valueSet, int valueSetId) {
    if valueSet.compose is r4:ValueSetCompose {
        foreach r4:ValueSetComposeInclude include in (<r4:ValueSetCompose>valueSet.compose).include {
            error? result = saveValueSetComposeInclude(include, valueSetId);
            if result is error {
                log:printError("Error while saving ValueSet concept: " + result.message());
            }
        }
    }
}

// Save a ValueSet concept to the database
isolated function saveValueSetComposeInclude(r4:ValueSetComposeInclude include, int valueSetId) returns error? {
    // concept can be a code system or a set of concepts
    if include.system is r4:uri {
        // find he CodeSystem in the database
        store:CodeSystem codesystem = check getStoreCodeSystemByURL(<string>include.system, include.'version);

        if include.concept is r4:ValueSetComposeIncludeConcept[] {
            foreach r4:ValueSetComposeIncludeConcept item in <r4:ValueSetComposeIncludeConcept[]>include.concept {
                // save valueset concept
                _ = start saveValueSetConcept(item.clone(), valueSetId, codesystem.codeSystemId);
            }
        } else {
            // save valueset code system
            _ = start saveValueSetCodeSystem(valueSetId, codesystem.codeSystemId);
        }
    }

    // check for nested ValueSet references
    else if include.valueSet is r4:canonical[] {
        // save valueset reference
        _ = start saveValueSetValueSet(valueSetId, <r4:canonical[]>include.valueSet.clone());
    }
}

isolated function saveValueSetConcept(r4:ValueSetComposeIncludeConcept concept, int valueSetId, int codeSystemId) returns error? {
    // find the concept in the database
    store:Concept dbConcept = check getStoreConceptByCode(codeSystemId, concept.code);

    store:ValueSetComposeIncludeInsert dbValueSetComposeIncludeInsert = {
        systemFlag: false,
        valueSetFlag: false,
        conceptFlag: true,
        valuesetValueSetId: valueSetId,
        codeSystemId: ()
    };
    int[] result = check sClient->/valuesetcomposeincludes.post([dbValueSetComposeIncludeInsert]);

    // save the concept reference to the database
    store:ValueSetComposeIncludeConceptInsert dbConceptInsert = {
        valuesetcomposeValueSetComposeIncludeId: result[0],
        conceptConceptId: dbConcept.conceptId
    };
    _ = check sClient->/valuesetcomposeincludeconcepts.post([dbConceptInsert]);
}

isolated function saveValueSetCodeSystem(int valueSetId, int codeSystemId) returns error? {
    store:ValueSetComposeIncludeInsert dbValueSetComposeIncludeInsert = {
        systemFlag: true,
        valueSetFlag: false,
        conceptFlag: false,
        valuesetValueSetId: valueSetId,
        codeSystemId: codeSystemId
    };
    _ = check sClient->/valuesetcomposeincludes.post([dbValueSetComposeIncludeInsert]);
}

isolated function saveValueSetValueSet(int valueSetId, r4:canonical[] valueSets) returns error? {
    // valueset reference can't be with a system or concepts
    store:ValueSetComposeIncludeInsert dbValueSetComposeIncludeInsert = {
        systemFlag: false,
        valueSetFlag: true,
        conceptFlag: false,
        valuesetValueSetId: valueSetId,
        codeSystemId: ()
    };

    int[] result = check sClient->/valuesetcomposeincludes.post([dbValueSetComposeIncludeInsert]);

    check saveNestedValueSetsInValueSetComposeInclude(valueSets, result[0]);
}

isolated function saveNestedValueSetsInValueSetComposeInclude(r4:canonical[] valueSets, int dbValueSetComposeIncludeId) returns error? {
    // find for valueset in the database
    foreach r4:canonical valueSet in valueSets {
        string[] split = regex:split(valueSet, string `\|`);
        var dbValueSet = getStoreValueSetByURL(split[0], split.length() > 1 ? split[1] : ());
        
        if dbValueSet is error {
            return r4:createFHIRError(
                    "ValueSet not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching ValueSet found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        // save the value set reference to the database
        store:ValueSetComposeIncludeValueSetInsert dbValueSetInsert = {
            valuesetcomposeValueSetComposeIncludeId: dbValueSetComposeIncludeId,
            valuesetValueSetId: dbValueSet.valueSetId
        };
        _ = check sClient->/valuesetcomposeincludevaluesets.post([dbValueSetInsert]);
    }
}
