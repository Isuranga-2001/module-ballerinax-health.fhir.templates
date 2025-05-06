import ballerina/persist as _;
import ballerinax/persist.sql;

@sql:Name {value: "codesystems"}
public type CodeSystem record {|
    @sql:Generated
    readonly int codeSystemId;
    string id;
    string url;
    string version;
    string name;
    string title;
    string status;
    string date;
    string publisher;
    byte[] codeSystem;
    Concept[] concepts;
|};

@sql:Name {value: "concepts"}
public type Concept record {|
    @sql:Generated
    readonly int conceptId;
    string code;
    byte[] concept;
    int? parentConceptId;
    CodeSystem codeSystem;
|};

@sql:Name {value: "valuesets"}
public type ValueSet record {|
    @sql:Generated
    readonly int valueSetId;
    string id;
    string url;
    string version;
    string name;
    string title;
    string status;
    string date;
    string publisher;
    byte[] valueSet;
    ValueSetConcept[] concepts;
|};

@sql:Name {value: "valueset_concepts"}
public type ValueSetConcept record {|
    @sql:Generated
    readonly int valueSetConceptId;
    string? system;
    string? version;
    string? code;
    byte[] concept;
    ValueSet valueSet;
|};