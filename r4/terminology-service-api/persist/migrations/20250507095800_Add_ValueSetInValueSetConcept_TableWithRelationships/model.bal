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
    ValueSetInValueSetConcept[] conceptsInValueSetConcepts;
|};

@sql:Name {value: "valueset_concepts"}
public type ValueSetConcept record {|
    @sql:Generated
    readonly int valueSetConceptId;
    string? id; // id for the include block
    string? system; // reference to the code system
    string? version; // version for the code system
    string? code; // code for the concept
    boolean systemFlag; // true if the system is a code system, false if it is a set of concepts
    byte[]? concept;
    ValueSet valueSet;
    ValueSetInValueSetConcept[] valueSets; // reference to the value sets
|};

@sql:Name {value: "valueset_in_valueset_concepts"}
public type ValueSetInValueSetConcept record {|
    @sql:Generated
    readonly int valueSetInValueSetConceptId;
	ValueSetConcept valuesetconcept;
	ValueSet valueset;
|};