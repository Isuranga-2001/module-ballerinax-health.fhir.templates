import terminology_service_api.store;

import ballerina/http;
import ballerina/log;
import ballerina/persist;
import ballerina/sql;
import ballerina/regex;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.terminology;

final store:Client sClient = check new ();

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
            codeSystem: check CodeSystemToByte(codeSystem)
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
        self.extractConceptsFromCodeSystem(codeSystem, response[0]);
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
            valueSet: check ValueSetToByte(valueSet)
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
        self.extractConceptsFromValueSet(valueSet, response[0]);
    }

    public isolated function findCodeSystem(r4:uri? system, string? id, string? version = ()) returns r4:CodeSystem|r4:FHIRError {
        r4:CodeSystem|r4:FHIRError|error dbCodeSystem;

        if id != () {
            dbCodeSystem = self.getCodeSystemByID(id, version);
        } else if system != () {
            dbCodeSystem = self.getCodeSystemByURL(system, version);
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
        terminology:CodeConceptDetails|r4:FHIRError valuesetConceptDetails = self.findConceptInValueSet(system, code, version);
        if valuesetConceptDetails !is r4:FHIRError {
            return valuesetConceptDetails;
        }
        
        // find the concept in the codesystem table
        terminology:CodeConceptDetails|r4:FHIRError conceptDetails = self.findConceptInCodeSystem(system, code, version);
        if conceptDetails is r4:FHIRError {
            return r4:createFHIRError(
                    conceptDetails.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = conceptDetails,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        return conceptDetails;
    }

    public isolated function findValueSet(r4:uri? system, string? id, string? version) returns r4:ValueSet|r4:FHIRError {
        r4:ValueSet|r4:FHIRError|error dbValueSet;

        if id != () {
            dbValueSet = self.getValueSetByID(id, version);
        } else if system != () {
            dbValueSet = self.getValueSetByURL(system, version);
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
        r4:CodeSystem|r4:FHIRError|persist:Error|error result = self.getCodeSystemByURL(system, version);
        if result is r4:CodeSystem {
            return true;
        }
        return false;
    }

    public isolated function isValueSetExist(r4:uri system, string version) returns boolean {
        r4:ValueSet|r4:FHIRError|persist:Error|error result = self.getValueSetByURL(system, version);
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
        store:CodeSystem[]|error dbCodeSystems = self.streamToStoreCodeSystem(codeSystemStream);

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

        stream<store:ValueSet, persist:Error?> valueSetStream = sClient->/valuesets(store:ValueSet, whereClause = whereClause);
        store:ValueSet[]|error dbValueSets = self.streamToStoreValueSet(valueSetStream);

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
            r4:ValueSet|error parsedValueSet = ByteToValueSet(dbValueSet.valueSet);
            if parsedValueSet is error {
                // Skip this ValueSet if parsing fails
                continue;
            }
            valueSetArray.push(parsedValueSet);
        }

        return valueSetArray;
    }

    private isolated function findConceptInValueSet(r4:uri system, r4:code code, string? version) returns terminology:CodeConceptDetails|r4:FHIRError {
        // check whether the value set exists
        var valueset = self.getStoreValueSetByURL(system, version);

        if valueset !is store:ValueSet {
            return r4:createFHIRError(
                    "CodeSystem not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching CodeSystem found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        sql:ParameterizedQuery sqlQueryWhereClause = `valuesetValueSetId = ${valueset.valueSetId} AND (code = ${code} OR systemFlag = TRUE)`;

        stream<store:ValueSetConcept, persist:Error?> conceptStream = sClient->/valuesetconcepts(store:ValueSetConcept, sqlQueryWhereClause);
        store:ValueSetConcept[]|error dbConcepts = self.streamToStoreValueSetConcept(conceptStream);

        if dbConcepts is error {
            return r4:createFHIRError(
                    "Error while searching for Concept, " + dbConcepts.message(),
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = dbConcepts,
                    httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }

        if dbConcepts.length() == 0 {
            // concept not found
            return r4:createFHIRError(
                    "Concept not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching Concept found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        store:ValueSetConcept[] valueSetSystems = [];

        // check whether the code in the concepts
        foreach store:ValueSetConcept dbConcept in dbConcepts {
            if dbConcept.code == code && dbConcepts[0].concept !is () {
                // concept found
                r4:ValueSetComposeIncludeConcept|error valueSetConcept = ByteToValueSetConcept(<byte[]>dbConcepts[0].concept);

                if valueSetConcept is error {
                    return r4:createFHIRError(
                            "Error while parsing Concept, " + valueSetConcept.message(),
                            r4:ERROR,
                            r4:INVALID_REQUIRED,
                            cause = valueSetConcept,
                            httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
                }

                return {
                    url: system,
                    concept: valueSetConcept
                };
            } else if dbConcept.systemFlag {
                // system flag is true, so add the system to the list
                valueSetSystems.push(dbConcept);
            }
        }

        // lookup the code in code system table
        if valueSetSystems.length() > 0 {
            foreach store:ValueSetConcept valueSetSystem in valueSetSystems {
                if valueSetSystem.system is string {
                    var result = self.findConceptInCodeSystem(<string>valueSetSystem.system, code, valueSetSystem.'version);
                    if result !is r4:FHIRError {
                        return result;
                    }
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

    private isolated function findConceptInCodeSystem(r4:uri system, r4:code code, string? version) returns terminology:CodeConceptDetails|r4:FHIRError {
        // check whether the code system exists
        var codeSystem = self.getStoreCodeSystemByURL(system, version);

        if codeSystem !is store:CodeSystem {
            return r4:createFHIRError(
                    "CodeSystem not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching CodeSystem found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        sql:ParameterizedQuery sqlQueryWhereClause = `code = ${code} AND codesystemCodeSystemId = ${codeSystem.codeSystemId}`;

        stream<store:Concept, persist:Error?> conceptStream = sClient->/concepts(store:Concept, whereClause = sqlQueryWhereClause);
        store:Concept[]|error dbConcept = self.streamToStoreConcept(conceptStream);

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

    // private functions
    private isolated function streamToStoreCodeSystem(stream<store:CodeSystem, persist:Error?> codeSystemStream) returns store:CodeSystem[]|error {
        store:CodeSystem[] dbCodeSystems = check from store:CodeSystem codeSystem in codeSystemStream
            select codeSystem;
        return dbCodeSystems;
    }

    private isolated function streamToStoreConcept(stream<store:Concept, persist:Error?> conceptStream) returns store:Concept[]|error {
        store:Concept[] dbConcepts = check from store:Concept concept in conceptStream
            select concept;
        return dbConcepts;
    }

    private isolated function streamToStoreValueSet(stream<store:ValueSet, persist:Error?> valueSetStream) returns store:ValueSet[]|error {
        store:ValueSet[] dbValueSets = check from store:ValueSet valueSet in valueSetStream
            select valueSet;
        return dbValueSets;
    }

    private isolated function streamToStoreValueSetConcept(stream<store:ValueSetConcept, persist:Error?> conceptStream) returns store:ValueSetConcept[]|error {
        store:ValueSetConcept[] dbConcepts = check from store:ValueSetConcept concept in conceptStream
            select concept;
        return dbConcepts;
    }

    private isolated function getAllCodeSystems() returns r4:CodeSystem[]|error {
        stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems();
        store:CodeSystem[] dbCodeSystems = check from var codeSystem in codeSystemStream
            select codeSystem;

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

    private isolated function getCodeSystemByID(string id, string? version = ()) returns r4:CodeSystem|error {
        sql:ParameterizedQuery sqlQueryWhereClause = version is ()
            ? `id = ${id} ORDER BY version DESC LIMIT 1`
            : `id = ${id} AND version = ${version}`;

        stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = sqlQueryWhereClause);
        store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream
            select codeSystem;

        if codeSystems.length() == 0 {
            return r4:createFHIRError(
                    "CodeSystem not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching CodeSystem found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        return ByteToCodeSystem(codeSystems[0].codeSystem);
    }

    private isolated function getCodeSystemByURL(string system, string? version = ()) returns r4:CodeSystem|error {
        store:CodeSystem storeCodeSystem = check self.getStoreCodeSystemByURL(system, version);

        return ByteToCodeSystem(storeCodeSystem.codeSystem);
    }

    private isolated function getStoreCodeSystemByURL(string system, string? version = ()) returns store:CodeSystem|error {
        sql:ParameterizedQuery sqlQueryWhereClause = version is ()
            ? `url = ${system} ORDER BY version DESC LIMIT 1`
            : `url = ${system} AND version = ${version}`;

        stream<store:CodeSystem, persist:Error?> codeSystemStream = sClient->/codesystems(store:CodeSystem, whereClause = sqlQueryWhereClause);
        store:CodeSystem[] codeSystems = check from var codeSystem in codeSystemStream
            select codeSystem;

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

    private isolated function getValueSetByID(string id, string? version = ()) returns r4:ValueSet|error {
        sql:ParameterizedQuery sqlQueryWhereClause = version is ()
            ? `id = ${id} ORDER BY version DESC LIMIT 1`
            : `id = ${id} AND version = ${version}`;

        stream<store:ValueSet, persist:Error?> valueSetStream = sClient->/valuesets(store:ValueSet, whereClause = sqlQueryWhereClause);
        store:ValueSet[] valueSets = check from var valueSet in valueSetStream
            select valueSet;

        if valueSets.length() == 0 {
            return r4:createFHIRError(
                    "ValueSet not found",
                    r4:ERROR,
                    r4:INVALID_REQUIRED,
                    cause = error("No matching ValueSet found"),
                    httpStatusCode = http:STATUS_NOT_FOUND);
        }

        // Assuming ByteToValueSet is available similar to ByteToCodeSystem
        return ByteToValueSet(valueSets[0].valueSet);
    }

    private isolated function getValueSetByURL(string system, string? version = ()) returns r4:ValueSet|error {
        store:ValueSet storeValueSet = check self.getStoreValueSetByURL(system, version);

        return ByteToValueSet(storeValueSet.valueSet);
    }

    private isolated function getStoreValueSetByURL(string system, string? version = ()) returns store:ValueSet|error {
        sql:ParameterizedQuery sqlQueryWhereClause = version is ()
            ? `url = ${system} ORDER BY version DESC LIMIT 1`
            : `url = ${system} AND version = ${version}`;

        stream<store:ValueSet, persist:Error?> valueSetStream = sClient->/valuesets(store:ValueSet, whereClause = sqlQueryWhereClause);
        store:ValueSet[] valueSets = check from var valueSet in valueSetStream
            select valueSet;

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

    private isolated function extractConceptsFromCodeSystem(r4:CodeSystem codeSystem, int codeSystemId) {
        if codeSystem.concept !is () {
            foreach var concept in <r4:CodeSystemConcept[]>codeSystem.concept {
                _ = start self.extractConceptsFromCodeSystemRecursive(concept.clone(), codeSystemId);
            }
        }
    }

    private isolated function extractConceptsFromCodeSystemRecursive(r4:CodeSystemConcept var_concept, int codeSystemId, int? parentId = ()) {
        int|error result = self.saveCodeSystemConcept(var_concept, codeSystemId, parentId);
        if result is error {
            log:printError("Error while saving concept: " + result.message());
        }

        if var_concept.concept !is () {
            foreach var subConcept in <r4:CodeSystemConcept[]>var_concept.concept {
                _ = start self.extractConceptsFromCodeSystemRecursive(subConcept.clone(), codeSystemId, (result is int) ? result : ());
            }
        }
    }

    private isolated function saveCodeSystemConcept(r4:CodeSystemConcept concept, int codeSystemId, int? parentId) returns int|error {
        store:ConceptInsert dbConceptInsert = {
            code: concept.code,
            concept: check ConceptToByte(concept),
            codesystemCodeSystemId: codeSystemId,
            parentConceptId: parentId
        };

        int[] id = check sClient->/concepts.post([dbConceptInsert]);
        return id[0];
    }

    // Extract concepts from a ValueSet and save them recursively
    private isolated function extractConceptsFromValueSet(r4:ValueSet valueSet, int valueSetId) {
        if valueSet.compose is r4:ValueSetCompose {
            foreach r4:ValueSetComposeInclude include in (<r4:ValueSetCompose>valueSet.compose).include {
                error? result = self.saveValueSetInclude(include, valueSetId);
                if result is error {
                    log:printError("Error while saving ValueSet concept: " + result.message());
                }
            }
        } else {
            return;
        }
    }

    // Save a ValueSet concept to the database
    private isolated function saveValueSetInclude(r4:ValueSetComposeInclude include, int valueSetId) returns error? {
        // concept can be a code system or a set of concepts
        if include.system is r4:uri {
            boolean isConceptIncluded = include.concept is r4:ValueSetComposeIncludeConcept[];

            if isConceptIncluded {
                foreach r4:ValueSetComposeIncludeConcept item in <r4:ValueSetComposeIncludeConcept[]>include.concept {
                    _ = start self.saveValueSetConcept(item.clone(), valueSetId, include.system, include.'version);
                }
            } else {
                store:ValueSetConceptInsert dbValueSetConceptInsert = {
                    code: (),
                    system: include.system,
                    'version: include.'version,
                    id: include.id,
                    systemFlag: true,
                    valueSetFlag: include.valueSet is r4:canonical[],
                    concept: (),
                    valuesetValueSetId: valueSetId
                };
                
                int[] result = check sClient->/valuesetconcepts.post([dbValueSetConceptInsert]);

                // check for nested ValueSet references
                // a valueset reference can be with a system, but only if the referenced ValueSet is based on that same system
                if dbValueSetConceptInsert.valueSetFlag {
                    check self.saveNestedValueSetsInValueSetConcept(<r4:canonical[]>include.valueSet, result[0]);
                }
            }
        }

        // check for nested ValueSet references
        if include.valueSet is r4:canonical[] {
            // valueset reference can't be with a system or concepts
            store:ValueSetConceptInsert dbValueSetConceptInsert = {
                code: (),
                system: (),
                'version: (),
                id: include.id,
                systemFlag: false,
                valueSetFlag: true,
                concept: (),
                valuesetValueSetId: valueSetId
            };

            int[] result = check sClient->/valuesetconcepts.post([dbValueSetConceptInsert]);

            check self.saveNestedValueSetsInValueSetConcept(<r4:canonical[]>include.valueSet, result[0]);
        }
    }

    private isolated function saveValueSetConcept(r4:ValueSetComposeIncludeConcept concept, int valueSetId, string? system, string? 'version) returns error? {
        store:ValueSetConceptInsert dbValueSetConceptInsert = {
            code: concept.code,
            system: system,
            'version: 'version,
            id: concept.id,
            systemFlag: false,
            valueSetFlag: false,
            concept: check ConceptToByte(concept),
            valuesetValueSetId: valueSetId
        };

        _ = check sClient->/valuesetconcepts.post([dbValueSetConceptInsert]);
    }

    private isolated function saveNestedValueSetsInValueSetConcept(r4:canonical[] valueSets, int valueSetConceptId) returns error? {
        // find for valueset in the database
        foreach r4:canonical valueSet in valueSets {
            string[] split = regex:split(valueSet, string `\|`);
            var dbValueSet = self.getStoreValueSetByURL(split[0], split.length() > 1 ? split[1] : ());
            
            if dbValueSet is error {
                return r4:createFHIRError(
                        "ValueSet not found",
                        r4:ERROR,
                        r4:INVALID_REQUIRED,
                        cause = error("No matching ValueSet found"),
                        httpStatusCode = http:STATUS_NOT_FOUND);
            }

            // save the value set reference to the database
            store:ValueSetInValueSetConceptInsert dbValueSetInValueSetConceptInsert = {
                valuesetconceptValueSetConceptId: valueSetConceptId,
                valuesetValueSetId: dbValueSet.valueSetId
            };
            _ = check sClient->/valuesetinvaluesetconcepts.post([dbValueSetInValueSetConceptInsert]);
        }
    }
}
