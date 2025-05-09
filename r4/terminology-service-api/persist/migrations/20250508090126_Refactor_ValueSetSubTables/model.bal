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
	ValueSetComposeIncludeCodeSystem[] valuesetcomposeincludecodesystem;
|};

@sql:Name {value: "concepts"}
public type Concept record {|
    @sql:Generated
    readonly int conceptId;
    string code;
    byte[] concept;
    int? parentConceptId;
    CodeSystem codeSystem;
	ValueSetComposeIncludeConcept[] valuesetcomposeincludeconcept;
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
    ValueSetComposeInclude[] composes;
    ValueSetComposeIncludeValueSet[] conceptsInValueSetConcepts;
|};

@sql:Name {value: "valueset_compose_includes"}
public type ValueSetComposeInclude record {|
    @sql:Generated
    readonly int valueSetComposeIncludeId;
    // string? system; // reference to the code system
    // string? version; // version for the code system
    // string? code; // code for the concept
    boolean systemFlag;
    boolean valueSetFlag;
    boolean conceptFlag;
    ValueSet valueSet;
    ValueSetComposeIncludeValueSet[] valueSets;
	ValueSetComposeIncludeCodeSystem[] valuesetcomposeincludecodesystem;
	ValueSetComposeIncludeConcept[] valuesetcomposeincludeconcept;
|};

@sql:Name {value: "valueset_compose_include_value_sets"}
public type ValueSetComposeIncludeValueSet record {|
    @sql:Generated
    readonly int valueSetComposeIncludeValueSetId;
	ValueSetComposeInclude valuesetCompose;
	ValueSet valueset;
|};

@sql:Name {value: "valueset_compose_include_code_systems"}
public type ValueSetComposeIncludeCodeSystem record {|
    @sql:Generated
    readonly int valueSetComposeIncludeCodeSystemId;
    ValueSetComposeInclude valuesetCompose;
    CodeSystem codeSystem;
|};

@sql:Name {value: "valueset_compose_include_concepts"}
public type ValueSetComposeIncludeConcept record {|
    @sql:Generated
    readonly int valueSetComposeIncludeConceptId;
    ValueSetComposeInclude valuesetCompose;
    Concept concept;
|};
