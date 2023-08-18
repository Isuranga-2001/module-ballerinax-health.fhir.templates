import ballerina/io;
import ballerina/http;
import ballerina/test;

http:Client testClient = check new ("http://localhost:9090");
map<string> cdaDocumentMap = {};

@test:BeforeSuite
function beforeSuiteFunc() returns error? {
    string patientDocument = check io:fileReadString("tests/test_patient_ccda_document.xml");
    string invalidDocument = check io:fileReadString("tests/test_invalid_ccda_document.xml");
    cdaDocumentMap["patient"] = patientDocument;
    cdaDocumentMap["invalid"] = invalidDocument;
}

@test:Config {}
function testCcdaDocumentToFhir() returns error? {
    http:Response|error response = testClient->/transform.post(cdaDocumentMap["patient"]);
    test:assertTrue(response is http:Response, "Error occurred while transforming CCDA document to FHIR!");
    if (response is http:Response) {
        test:assertEquals(response.statusCode,200, "Response status code mismatched!");
        json jsonPayload = check response.getJsonPayload();
        test:assertEquals(jsonPayload.resourceType, "Bundle", "Error occurred while transforming CCDA document to FHIR!");
        json[] entries = <json[]>check jsonPayload.entry;
        test:assertEquals(entries.length(), 2, "Incorrect number of bundle entries from the conversion!");
        test:assertEquals(check entries[0].'resource.resourceType, "Patient", "Incorrect resource type from the conversion!");
    }
}

@test:Config {}
function testErrorneousCcdaDocument() returns error? {
    http:Response|error response = testClient->/transform.post(cdaDocumentMap["invalid"]);
    if (response is http:Response) {
        test:assertEquals(response.statusCode,400, "Response status code mismatched!");
        json jsonPayload = check response.getJsonPayload();
        test:assertEquals(jsonPayload.resourceType, "OperationOutcome", "Response should be an OperationOutcome!");
        json[] issues = <json[]>check jsonPayload.issue;
        test:assertEquals(check issues[0].details.text, "Invalid xml document.", "Incorrect error message from the invalid document conversion!");
    }
}

