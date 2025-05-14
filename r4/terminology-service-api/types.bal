import ballerinax/health.fhir.r4;

public type CodeSystemValueSetJson record {|
    json[] codeSystems;
    json[] valueSets;
|};

public type ParseCodeSystem record {|
    *r4:DomainResource;

    r4:RESOURCE_NAME_CODESYSTEM resourceType = r4:RESOURCE_NAME_CODESYSTEM;

    r4:BaseCodeSystemMeta meta = {
        profile: [r4:PROFILE_BASE_CODESYSTEM]
    };
    r4:dateTime date?;
    r4:markdown copyright?;
    r4:Extension[] extension?;
    r4:canonical valueSet?;
    r4:markdown purpose?;
    r4:CodeSystemConcept[] concept?;
    r4:CodeableConcept[] jurisdiction?;
    r4:Extension[] modifierExtension?;
    r4:markdown description?;
    boolean experimental?;
    r4:code language?;
    string title?;
    r4:CodeSystemContent content?;
    r4:CodeSystemHierarchyMeaning hierarchyMeaning?;
    r4:ContactDetail[] contact?;
    r4:CodeSystemProperty[] property?;
    string id?;
    r4:Narrative text?;
    r4:Identifier[] identifier?;
    boolean caseSensitive?;
    boolean versionNeeded?;
    r4:unsignedInt count?;
    string 'version?;
    r4:uri url?;
    r4:CodeSystemFilter[] filter?;
    r4:canonical supplements?;
    r4:Resource[] contained?;
    boolean compositional?;
    string name?;
    r4:uri implicitRules?;
    string publisher?;
    r4:UsageContext[] useContext?;
    r4:CodeSystemStatus status?;
    never...;
|};

public type ParseValueSet record {|
    *r4:DomainResource;

    r4:RESOURCE_NAME_VALUESET resourceType = r4:RESOURCE_NAME_VALUESET;

    r4:BaseValueSetMeta meta = {
        profile: [r4:PROFILE_BASE_VALUESET]
    };
    r4:dateTime date?;
    r4:markdown copyright?;
    r4:Extension[] extension?;
    r4:markdown purpose?;
    r4:CodeableConcept[] jurisdiction?;
    r4:Extension[] modifierExtension?;
    r4:markdown description?;
    boolean experimental?;
    r4:code language?;
    string title?;
    r4:ContactDetail[] contact?;
    string id?;
    r4:Narrative text?;
    r4:Identifier[] identifier?;
    string 'version?;
    r4:uri url?;
    r4:ValueSetExpansion expansion?;
    r4:Resource[] contained?;
    boolean immutable?;
    r4:ValueSetCompose compose?;
    string name?;
    r4:uri implicitRules?;
    string publisher?;
    r4:UsageContext[] useContext?;
    r4:ValueSetStatus status?;
    never...;
|};
