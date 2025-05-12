import ballerinax/health.fhir.r4.terminology;

//Congifurations
configurable boolean test_env = ?;

//Constants
public string TABLE_NAME = "";
public final string TABLE_NAME_CODESYSTEM = "code_system";
public final string TABLE_NAME_CONCEPT = "concept";
public final string TABLE_NAME_VALUESET = "value_set";
public final string TYPE_HEADER = "x-terminology-type";

final TerminologySource db_terminology_source = new ();

// Constants
final terminology:Terminology? terminology_source = db_terminology_source;
final boolean IS_EXTERNAL_TERMINOLOGY_SOURCE_ENABLED = terminology_source is terminology:Terminology;