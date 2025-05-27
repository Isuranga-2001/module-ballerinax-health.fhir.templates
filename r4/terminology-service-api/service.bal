import ballerina/http;
import ballerina/log;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.international401;

listener http:Listener interceptorListener = new (9089, timeout = 0);

service http:InterceptableService / on interceptorListener {

    public function createInterceptors() returns FHIRResponseErrorInterceptor {
        return new FHIRResponseErrorInterceptor();
    }

    isolated resource function get fhir/r4/ValueSet/\$expand(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: ValueSet Expand");

        r4:ValueSet valueSet = check valueSetExpansionGet(request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(valueSet, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/ValueSet/\$expand(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: ValueSet Expand");

        r4:ValueSet valueSet = check valueSetExpansionPost(request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(valueSet, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/ValueSet/\$validate\-code(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: ValueSet Validate Code");

        international401:Parameters parameters = check valueSetValidateCodeGet(request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(parameters, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/ValueSet/\$validate\-code(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: ValueSet Validate Code");

        international401:Parameters parameters = check valueSetValidateCodePost(request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(parameters, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/ValueSet/[string id]/\$expand(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug(string `FHIR Terminology request is received. Interaction: ValueSet Expand with ValueSet Id: ${id}`);

        r4:ValueSet valueSet = check valueSetExpansionGet(request, id);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(valueSet, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/ValueSet/[string id]/\$validate\-code(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug(string `FHIR Terminology request is received. Interaction: ValueSet Validate Code with ValueSet Id: ${id}`);

        international401:Parameters parameters = check valueSetValidateCodeGet(request, id);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(parameters, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/ValueSet/[string id](http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug(string `FHIR Terminology request is received. Interaction: ValueSet Get with ValueSet Id: ${id}`);

        r4:ValueSet valueSet = check readValueSetById(id);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(valueSet, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/ValueSet(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: ValueSet Search");

        r4:Bundle valueSet = check searchValueSet(request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(valueSet, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/ValueSet(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: Add new ValueSet");

        _ = check addValueSet(request);

        http:Response successResponse = new;
        successResponse.statusCode = http:STATUS_CREATED;
        return successResponse;
    }

    // ===============================================================================================================================

    isolated resource function get fhir/r4/CodeSystem/\$lookup(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: CodeSystem Lookup");

        international401:Parameters codeSystemLookUpResult = check codeSystemLookUpGet(ctx, request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(codeSystemLookUpResult, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/CodeSystem/\$lookup(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: CodeSystem Lookup");

        international401:Parameters result = check codeSystemLookUpPost(ctx, request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(result, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/CodeSystem/\$subsumes(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: CodeSystem Subsume");

        international401:Parameters subsumesResult = check subsumesGet(ctx, request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(subsumesResult, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/CodeSystem/\$subsumes(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: CodeSystem Subsume");

        international401:Parameters result = check subsumesPost(ctx, request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(result, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/CodeSystem/[string id]/\$lookup(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug(string `FHIR Terminology request is received. Interaction: CodeSystem Lookup with Id: ${id}`);

        international401:Parameters codeSystemLookUpResult = check codeSystemLookUpGet(ctx, request, id);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(codeSystemLookUpResult, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/CodeSystem/[string id](http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug(string `FHIR Terminology request is received. Interaction: CodeSystem Get with Id: ${id}`);

        r4:CodeSystem codeSystem = check readCodeSystemById(id);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(codeSystem, FHIR_JSON);
        return response;
    }

    isolated resource function get fhir/r4/CodeSystem(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: CodeSystem Search");

        r4:Bundle codeSystem = check searchCodeSystem(request);

        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(codeSystem, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/CodeSystem(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: Add new CodeSystem");

        _ = check addCodeSystem(request);

        http:Response successResponse = new;
        successResponse.statusCode = http:STATUS_CREATED;
        return successResponse;
    }

    // ===============================================================================================================================

    isolated resource function post fhir/r4(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: Batch");

        r4:Bundle result = check batchValidateValueSets(request);
        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(result, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/\$upload(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: Create");

        r4:FHIRError? response = upload(request);

        if response is r4:FHIRError {
            return response;
        } else {
            http:Response successResponse = new;
            successResponse.statusCode = http:STATUS_CREATED;
            successResponse.setJsonPayload(response.toJson());
            return successResponse;
        }
    }

    isolated resource function get fhir/r4/Concept/\$find\-code(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: Find Code");

        r4:Bundle result = check findCodeGet(request);

        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(result, FHIR_JSON);
        return response;
    }

    isolated resource function post fhir/r4/Concept/\$find\-code(http:RequestContext ctx, http:Request request) returns http:Response|r4:FHIRError {
        log:printDebug("FHIR Terminology request is received. Interaction: Find Code (POST)");

        r4:Bundle result = check findCodePost(request);

        http:Response response = new;
        response.statusCode = http:STATUS_OK;
        response.setPayload(result, FHIR_JSON);
        return response;
    }
}
