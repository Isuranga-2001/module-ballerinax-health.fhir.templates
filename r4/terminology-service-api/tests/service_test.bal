import ballerina/http;
import ballerina/test;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;
import ballerinax/health.fhir.r4.terminology;

http:Client baseClient = check new ("http://localhost:9090/fhir/r4");
http:Client csClient = check new ("http://localhost:9090/fhir/r4/Codesystem");
http:Client vsClient = check new ("http://localhost:9090/fhir/r4/Valueset");

@test:Config {
    groups: ["codesystem", "get_by_id_codesystem", "successful_scenario"]
}
public function getByIdCodeSystem1() returns error? {
    http:Response response = check csClient->get("/account-status");

    json expected = returnCodeSystemData("account-status");
    test:assertEquals(response.getJsonPayload(), expected);
}

@test:Config {
    groups: ["codesystem", "get_by_id_codesystem", "successful_scenario"]
}
public function getByIdCodeSystem2() returns error? {
    http:Response response = check csClient->get("/account-status%7C4.0.1");

    json expected = returnCodeSystemData("account-status");
    test:assertEquals(response.getJsonPayload(), expected);
}

@test:Config {
    groups: ["codesystem", "get_by_id_codesystem", "successful_scenario"]
}
public function searchCodeSystem1() returns error? {
    http:Response response = check csClient->get("?url=http://hl7.org/fhir/account-status");
    json actualJson = check response.getJsonPayload();
    r4:Bundle actual = check actualJson.cloneWithType(r4:Bundle);

    r4:Bundle expected = check returnCodeSystemData("account-status-bundle").cloneWithType(r4:Bundle);
    expected.meta.lastUpdated = actual.meta.lastUpdated;
    expected.'type = r4:BUNDLE_TYPE_SEARCHSET;

    test:assertEquals(actual.toJson(), expected.toJson());
}

@test:Config {
    groups: ["codesystem", "get_by_id_codesystem", "successful_scenario"]
}
public function searchCodeSystem2() returns error? {
    http:Response response = check csClient->get("?url=http://hl7.org/fhir/account-status&version=4.0.1&title=AccountStatus&status=draft&count=10&offset=0&name=AccountStatus&publisher=HL7%20%28FHIR%20Project%29");
    json actualJson = check response.getJsonPayload();
    r4:Bundle actual = check actualJson.cloneWithType(r4:Bundle);

    r4:Bundle expected = check returnCodeSystemData("account-status-bundle").cloneWithType(r4:Bundle);
    expected.meta.lastUpdated = actual.meta.lastUpdated;

    test:assertEquals(actual.toJson(), expected.toJson());
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "successful_scenario"]
}
public function lookupCodeSystem1() returns error? {
    http:Response response = check csClient->get("/%24lookup?system=http://hl7.org/fhir/account-status&code=inactive");
    json actual = check response.getJsonPayload();

    json expected = returnCodeSystemData("account-status-inactive");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "successful_scenario"]
}
public function lookupCodeSystem2() returns error? {
    http:Response response = check csClient->get("/account-status/%24lookup?code=inactive", ());
    json actual = check response.getJsonPayload();

    json expected = returnCodeSystemData("account-status-inactive");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "successful_scenario"]
}
public function lookupCodeSystem3() returns error? {
    r4:Coding|r4:FHIRError coding = terminology:createCoding("http://hl7.org/fhir/account-status", "inactive");
    international401:Parameters p = {'parameter: [{name: "coding", valueCoding: check coding}]} ;
    http:Response response = check csClient->post("/%24lookup", p);
    json actual = check response.getJsonPayload();

    json expected = returnCodeSystemData("account-status-inactive");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem4() returns error? {
    http:Response response = check csClient->post("/%24lookup", ());
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Empty request payload");
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem5() returns error? {
    http:Response response = check csClient->get("/%24lookup?code=inactive", ());
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedjson = returnCodeSystemData("lookup-error");
    r4:OperationOutcome expected = check expectedjson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem6() returns error? {
    json codingJson = returnCodeSystemData("invalid-json-payload");
    http:Response response = check csClient->post("/%24lookup", codingJson);
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedjson = returnCodeSystemData("lookup-error2");
    r4:OperationOutcome expected = check expectedjson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem7() returns error? {
    http:Response response = check csClient->post("/%24lookup", ());
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Empty request payload");
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem8() returns error? {
    http:Response response = check csClient->post("/%24lookup", {});
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Invalid Coding value");
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem9() returns error? {
    international401:Parameters parameters = {'parameter: [{name: "sample"}]} ;
    http:Response response = check csClient->post("/%24lookup", parameters);
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Invalid request payload");
}

@test:Config {
    groups: ["codesystem", "lookup_codesystem", "failure_scenario"]
}
public function lookupCodeSystem10() returns error? {
    r4:Coding coding = check terminology:createCoding("http://hl7.org/fhir/account-status", "inactive");
    coding.system = ();
    international401:Parameters parameters = {'parameter: [{name: "coding", valueCoding: coding}]};
    http:Response response = check csClient->post("/%24lookup", parameters);
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Can not find a CodeSystem");
}

@test:Config {
    groups: ["codesystem", "subsume_codesystem", "successful_scenario"]
}
public function subsumeCodeSystem1() returns error? {
    http:Response response = check csClient->get("/%24subsumes?codeA=Type&codeB=Any&system=http://hl7.org/fhir/abstract-types", ());
    json actual = check response.getJsonPayload();

    json expected = returnCodeSystemData("subsume-notequal");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "subsume_codesystem", "successful_scenario"]
}
public function subsumeCodeSystem2() returns error? {
    http:Response response = check csClient->get("/%24subsumes?codeA=Type&codeB=Type&system=http://hl7.org/fhir/abstract-types", ());
    json actual = check response.getJsonPayload();

    json expected = returnCodeSystemData("subsume-equal");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "subsume_codesystem", "successful_scenario"]
}
public function subsumeCodeSystem3() returns error? {

    r4:Coding codingA = check terminology:createCoding("http://hl7.org/fhir/account-status", "inactive");
    r4:Coding codingB = check terminology:createCoding("http://hl7.org/fhir/account-status", "inactive");

    international401:ParametersParameter cA = {name: "codingA", valueCoding: codingA};
    international401:ParametersParameter cB = {name: "codingB", valueCoding: codingB};
    international401:ParametersParameter system = {name: "system", valueUri: "http://hl7.org/fhir/account-status"};
    international401:Parameters requestPayload = {'parameter: [cA, cB, system]};

    http:Response response = check csClient->post("/%24subsumes", requestPayload);
    json actual = check response.getJsonPayload();

    json expected = returnCodeSystemData("subsume-equal");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "subsume_codesystem", "failure_scenario"]
}
public function subsumeCodeSystem5() returns error? {

    http:Response response = check csClient->get("/%24subsumes?codeA=Type&codeB=Type", ());
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedjson = returnCodeSystemData("subsume-error");
    r4:OperationOutcome expected = check expectedjson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "subsume_codesystem", "failure_scenario"]
}
public function subsumeCodeSystem6() returns error? {

    json requestJson = returnCodeSystemData("invalid-json-payload");
    http:Response response = check csClient->post("/%24subsumes", requestJson);
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedjson = returnCodeSystemData("subsume-error2");
    r4:OperationOutcome expected = check expectedjson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "subsume_codesystem", "failure_scenario"]
}
public function subsumeCodeSystem7() returns error? {
    http:Response response = check csClient->post("/%24subsumes", ());
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Empty request payload or invalid json format");
}

// ===========================Value set======================================

@test:Config {
    groups: ["valueSet", "get_by_id_valueSet", "successful_scenario"]
}
public function getByIdValueSet1() returns error? {
    http:Response response = check vsClient->get("/account-status");

    json expected = returnValueSetData("account-status");
    test:assertEquals(response.getJsonPayload(), expected);
}

@test:Config {
    groups: ["valueSet", "get_by_id_valueSet", "successful_scenario"]
}
public function getByIdValueSet2() returns error? {
    http:Response response = check vsClient->get("/account-status%7C4.0.1");

    json expected = returnValueSetData("account-status");
    test:assertEquals(response.getJsonPayload(), expected);
}

@test:Config {
    groups: ["valueset", "search_valueset", "successful_scenario"]
}
public function searchValueSet1() returns error? {
    http:Response response = check vsClient->get("?url=http://hl7.org/fhir/ValueSet/abstract-types");
    json actualJson = check response.getJsonPayload();
    r4:Bundle actual = check actualJson.cloneWithType(r4:Bundle);

    r4:Bundle expected = check returnValueSetData("account-status-bundle").cloneWithType(r4:Bundle);
    expected.meta.lastUpdated = actual.meta.lastUpdated;
    test:assertEquals(response.getJsonPayload(), expected.toJson());
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "successful_scenario"]
}
public function validateCodeValueSet1() returns error? {
    http:Response response = check vsClient->get("/%24validate-code?system=http://hl7.org/fhir/ValueSet/account-status&code=inactive", ());
    json actual = check response.getJsonPayload();

    json expected = returnValueSetData("validate-code");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "successful_scenario"]
}
public function validateCodeValueSet2() returns error? {
    json requestPayload = returnValueSetData("account-status-as-parameter");
    http:Response response = check vsClient->post("/%24validate-code", requestPayload);
    json actual = check response.getJsonPayload();

    json expected = returnValueSetData("validate-code");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "successful_scenario"]
}
public function validateCodeValueSet3() returns error? {
    http:Response response = check vsClient->get("/account-status/%24validate-code?code=inactive", ());
    json actual = check response.getJsonPayload();

    json expected = returnValueSetData("validate-code");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "successful_scenario"]
}
public function validateCodeValueSet4() returns error? {
    json requestPayload = returnValueSetData("account-status-as-parameter");
    http:Response response = check vsClient->post("/%24validate-code", requestPayload);
    json actual = check response.getJsonPayload();

    json expected = returnValueSetData("validate-code");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "successful_scenario"]
}
public function validateCodeValueSet5() returns error? {
    json requestPayload = returnValueSetData("account-status-as-parameter2");

    http:Response response = check vsClient->post("/%24validate-code", requestPayload);
    json actual = check response.getJsonPayload();

    json expected = returnValueSetData("validate-code");
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "failure_scenario"]
}
public function validateCodeValueSet6() returns error? {
    http:Response response = check vsClient->post("/%24validate-code", ());
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Empty request payload");
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "failure_scenario"]
}
public function validateCodeValueSet7() returns error? {
    http:Response response = check vsClient->post("/%24validate-code", {});
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Invalid request payload");
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "failure_scenario"]
}
public function validateCodeValueSet8() returns error? {
    json requestPayload = returnValueSetData("coding-as-parameter");
    http:Response response = check vsClient->post("/%24validate-code", requestPayload);
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Invalid request payload");
}

@test:Config {
    groups: ["valueset", "validate_code_valueset", "failure_scenario"]
}
public function validateCodeValueSet9() returns error? {
    http:Response response = check vsClient->get("/%24validate-code");
    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Can not find a ValueSet, Code value is missing");
}

@test:Config {
    groups: ["valueset", "expand_valueset", "successful_scenario"]
}
public function expandValueSet1() returns error? {
    http:Response response = check vsClient->get("/%24expand?url=http://hl7.org/fhir/ValueSet/account-status&filter=account", ());
    json actualJson = check response.getJsonPayload();
    r4:ValueSet actual = check actualJson.cloneWithType(r4:ValueSet);

    json expectedJson = returnValueSetData("expanded-account-status");
    r4:ValueSet expected = check expectedJson.cloneWithType(r4:ValueSet);

    expected.expansion.timestamp = (<r4:ValueSetExpansion>actual.expansion).timestamp;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "expand_valueset", "successful_scenario"]
}
public function expandValueSet2() returns error? {
    http:Response response = check vsClient->get("/account-status/%24expand?filter=account", ());
    json actualJson = check response.getJsonPayload();
    r4:ValueSet actual = check actualJson.cloneWithType(r4:ValueSet);

    json expectedJson = returnValueSetData("expanded-account-status");
    r4:ValueSet expected = check expectedJson.cloneWithType(r4:ValueSet);

    expected.expansion.timestamp = (<r4:ValueSetExpansion>actual.expansion).timestamp;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "expand_valueset", "successful_scenario"]
}
public function expandValueSet3() returns error? {
    json requestPayload = returnValueSetData("account-status-as-parameter");
    http:Response response = check vsClient->post("/%24expand?filter=account", requestPayload);

    json actualJson = check response.getJsonPayload();
    r4:ValueSet actual = check actualJson.cloneWithType(r4:ValueSet);

    json expectedJson = returnValueSetData("expanded-account-status");
    r4:ValueSet expected = check expectedJson.cloneWithType(r4:ValueSet);

    expected.expansion.timestamp = (<r4:ValueSetExpansion>actual.expansion).timestamp;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "expand_valueset", "failure_scenario"]
}
public function expandValueSet4() returns error? {
    http:Response response = check vsClient->post("/%24expand", ());

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedJson = returnValueSetData("expand-error");
    r4:OperationOutcome expected = check expectedJson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "expand_valueset", "failure_scenario"]
}
public function expandValueSet5() returns error? {
    http:Response response = check vsClient->post("/%24expand", {});

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);
    test:assertEquals((<r4:CodeableConcept>actual.issue[0].details).text, "Invalid request payload");
}

@test:Config {
    groups: ["codesystem", "concepts", "successful_scenario"]
}
public function testCodeSystemConceptPropertiesAndDesignations() returns error? {
    r4:CodeSystemConcept concept = check returnCodeSystemData("designation-input").cloneWithType(r4:CodeSystemConcept);

    international401:Parameters parameters = codesystemConceptsToParameters(concept);
    json actualJson = parameters.toJson();

    json expectedJson = returnCodeSystemData("designation-expected");
    test:assertEquals(actualJson, expectedJson);
}

@test:Config {
    groups: ["codesystem", "concepts", "successful_scenario"]
}
public function testCodeSystemConceptsArray() returns error? {
    json jsonData = returnCodeSystemData("concepts-array-input");
    r4:CodeSystemConcept[] concepts = [];

    if jsonData is json[] {
        foreach var item in jsonData {
            r4:CodeSystemConcept concept = check item.cloneWithType(r4:CodeSystemConcept);
            concepts.push(concept);
        }
    } else {
        return error("Invalid JSON data format");
    }

    international401:Parameters parameters = codesystemConceptsToParameters(concepts);
    json actualJson = parameters.toJson();

    json expectedJson = returnCodeSystemData("concepts-array-expected");
    test:assertEquals(actualJson, expectedJson);
}

@test:Config {
    groups: ["valueset", "batch_validate_valueset", "successful_scenario"]
}
public function testBatchValidateValueSetsValid() returns error? {
    json requestPayload = returnBatchData("valid-batch-request");
    json expectedResponse = returnBatchData("valid-batch-response");

    http:Response response = check baseClient->post("/", requestPayload);
    test:assertEquals(response.getJsonPayload(), expectedResponse);
}

@test:Config {
    groups: ["valueset", "batch_validate_valueset", "failure_scenario"]
}
public function testBatchValidateValueSetsInvalidJson() returns error? {
    json requestPayload = returnBatchData("invalid-json-batch-request");
    http:Response response = check baseClient->post("/", requestPayload);

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedJson = returnBatchData("invalid-json-batch-response");
    r4:OperationOutcome expected = check expectedJson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "batch_validate_valueset", "failure_scenario"]
}
public function testBatchValidateValueSetsNotBatchType() returns error? {
    json requestPayload = returnBatchData("not-batch-type-request");
    http:Response response = check baseClient->post("/", requestPayload);

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedJson = returnBatchData("not-batch-type-response");
    r4:OperationOutcome expected = check expectedJson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "batch_validate_valueset", "failure_scenario"]
}
public function testBatchValidateValueSetsNoEntries() returns error? {
    json requestPayload = returnBatchData("no-entries-batch-request");
    http:Response response = check baseClient->post("/", requestPayload);

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedJson = returnBatchData("no-entries-batch-response");
    r4:OperationOutcome expected = check expectedJson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "add_codesystem", "successful_scenario"]
}
public function testAddValidCodeSystem() returns error? {
    json requestPayload = returnCodeSystemData("add-valid-codesystem");

    http:Response response = check csClient->post("/", requestPayload);

    // check the response status code is 201 or not
    test:assertEquals(response.statusCode, 201);
}

@test:Config {
    groups: ["codesystem", "add_codesystem", "failure_scenario"]
}
public function testAddInvalidCodeSystem() returns error? {
    json codingJson = returnCodeSystemData("add-invalid-codesystem");
    http:Response response = check csClient->post("/", codingJson);

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedjson = returnCodeSystemData("add-invalid-codesystem-response");
    r4:OperationOutcome expected = check expectedjson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["codesystem", "add_codesystem", "failure_scenario"]
}
public function testAddEmptyCodeSystemPayload() returns error? {
    http:Response response = check csClient->post("/", {});

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedjson = returnCodeSystemData("add-invalid-codesystem-response");
    r4:OperationOutcome expected = check expectedjson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "add_valueset", "successful_scenario"]
}
public function testAddValidValueSet() returns error? {
    json requestPayload = returnValueSetData("add-valid-valueset");

    http:Response response = check vsClient->post("/", requestPayload);

    // check the response status code is 201 or not
    test:assertEquals(response.statusCode, 201);
}

@test:Config {
    groups: ["valueset", "add_valueset", "failure_scenario"]
}
public function testAddInvalidValueSet() returns error? {
    json valueSetJson = returnValueSetData("add-invalid-valueset");
    http:Response response = check vsClient->post("/", valueSetJson);

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedJson = returnValueSetData("add-invalid-valueset-response");
    r4:OperationOutcome expected = check expectedJson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}

@test:Config {
    groups: ["valueset", "add_valueset", "failure_scenario"]
}
public function testAddEmptyValueSetPayload() returns error? {
    http:Response response = check vsClient->post("/", {});

    json actualJson = check response.getJsonPayload();
    r4:OperationOutcome actual = check actualJson.cloneWithType(r4:OperationOutcome);

    json expectedJson = returnValueSetData("add-invalid-valueset-response");
    r4:OperationOutcome expected = check expectedJson.cloneWithType(r4:OperationOutcome);

    expected.issue[0].diagnostics = (<r4:OperationOutcomeIssue[]>actual.issue)[0].diagnostics;
    test:assertEquals(actual, expected);
}
