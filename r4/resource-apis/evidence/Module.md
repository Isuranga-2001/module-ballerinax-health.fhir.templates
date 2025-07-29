# FHIR Evidence API Template

This Ballerina-based template implementation provides a RESTful FHIR API for managing `Evidence` resources, adhering to the FHIR R4 specification. The API is designed to support CRUD operations International FHIR R4 Evidence FHIR API.

| Module/Element       | Version |
| -------------------- | ------- |
| FHIR version         | r4 |
| Implementation Guide | [http://hl7.org/fhir](http://hl7.org/fhir) |
| Profile URL          |[http://hl7.org/fhir/StructureDefinition/synthesis](http://hl7.org/fhir/StructureDefinition/synthesis), [http://hl7.org/fhir/StructureDefinition/Evidence](http://hl7.org/fhir/StructureDefinition/Evidence)|

> **_Note:_**  If you are having FHIR profiles from regional or custom implementation guides, you can use the Ballerina Health tool to generate the FHIR API templates for the FHIR profiles. For more information, see the [Ballerina Health tool](https://ballerina.io/learn/health-tool/#fhir-template-generation).

- [Ballerina](https://ballerina.io/downloads/) (2201.10.2 or later)
- [VSCode](https://code.visualstudio.com/download) as the IDE and install the required vscode plugins
    - Ballerina (https://marketplace.visualstudio.com/items?itemName=WSO2.ballerina)
    - Ballerina Integrator (https://marketplace.visualstudio.com/items?itemName=WSO2.ballerina-integrator)

```sh
bal new -t healthcare/health.fhir.r4.international401.evidence EvidenceAPI
```

Run the Ballerina project created by the service template by executing:
```sh
bal run
```
Once successfully executed, the listener will be started at port `9090`. Then, you can invoke the service using the following curl command:
```sh
curl http://localhost:9090/fhir/r4/Evidence
```
Now, the service will be invoked and return an `OperationOutcome`, until the code template is implemented completely.

> **_Note:_**  This template is designed to be used as a starting point for implementing the FHIR API. The template is not complete and will return an `OperationOutcome` until the code is implemented.


```http
GET /fhir/r4/Evidence/{id}
```
- **Response:** Returns a `Evidence` resource or an `OperationOutcome` if not found.

```http
GET /fhir/r4/Evidence/{id}/_history/{vid}
```
- **Response:** Returns a specific historical version of a `Evidence` resource.

```http
GET /fhir/r4/Evidence
```
- **Response:** Returns a `Bundle` containing matching `Evidence` resources.

```http
POST /fhir/r4/Evidence
```
- **Request Body:** `Evidence` resource.
- **Response:** Returns the created `Evidence` resource.

```http
PUT /fhir/r4/Evidence/{id}
```
- **Request Body:** Updated `Evidence` resource.
- **Response:** Returns the updated `Evidence` resource.

```http
PATCH /fhir/r4/Evidence/{id}
```
- **Request Body:** JSON Patch object.
- **Response:** Returns the updated `Evidence` resource.

```http
DELETE /fhir/r4/Evidence/{id}
```
- **Response:** Returns an `OperationOutcome` indicating success or failure.

```http
GET /fhir/r4/Evidence/{id}/_history
```
- **Response:** Returns a `Bundle` of historical versions of the `Evidence` resource.

```http
GET /fhir/r4/Evidence/_history
```
- **Response:** Returns a `Bundle` of historical versions of all `Evidence` resources.

The template is designed to work as a Facade API to expose your data as in FHIR. The following are the key steps which you can follow to implement the business logic:
- Handle business logic to work with search parameters.
- Implement the source system backend connection logic to fetch data.
- Perform data mapping inside the service to align with the FHIR models.

Modify `apiConfig` in the `fhirr4:Listener` initialization if needed to adjust service settings.

The `apiConfig` object is used to configure the FHIR API. By default, it consists of the search parameters for the FHIR API defined for the Implementation Guide. If there are custom search parameters, they can be defined in the `apiConfig` object. Following is an example of how to add a custom search parameter:

```json
        searchParameters: [
          ....
          {
              name: "custom-search-parameter", // Custom search parameter name
              active: true // Whether the search parameter is active
              information: { // Optional information about the search parameter
                  description: "Custom search parameter description",
                  builtin: false,
              }
          }
        ]
  ```


Following are the steps to add a custom operation to the FHIR API template:

1. The `apiConfig` object is used to configure the FHIR API. By default, it consists of the operations for the FHIR API defined for the Implementation Guide. If there are custom operations, they can be defined in the `apiConfig` object. Following is an example of how to add a custom operation:
```json
        operations: [
          ....
          {
              name: "custom-operation", // Custom operation name
              active: true // Whether the operation is active
              information: { // Optional information about the operation
                  description: "Custom operation description",
                  builtin: false,
              }
          }
        ]
  ```
  2. Add the context related to the custom operation in the service.bal file. Following is an example of how to add a custom operation:
  ```typescript
    isolated resource function post fhir/r4/Evidence/\$custom\-operation(r4:FHIRContext fhirContext, Evidence procedure) returns r4:OperationOutcome|r4:FHIRError {
        return r4:createFHIRError("Not implemented", r4:ERROR, r4:INFORMATIONAL, httpStatusCode = http:STATUS_NOT_IMPLEMENTED);
    }
  ```

Additionally, If you want to have a custom profile or a combination of profiles served from this same API template, you can add them to this FHIR API template. To add a custom profile, follow the steps below:

- Add the profile type to the aggregated resource type.
  - **Example:** `public type Evidence r4:Evidence|<Other_Evidence_Profile>;`
- Add the new profile URL in `api_config.bal` file. You need to add it as a string inside the `profiles` array.
  - **Example:**
    ```ballerina
    profiles: ["http://hl7.org/fhir/StructureDefinition/Evidence", "new_profile_url"]
    ```

This project is subject to the [WSO2 Software License](../LICENCE).

