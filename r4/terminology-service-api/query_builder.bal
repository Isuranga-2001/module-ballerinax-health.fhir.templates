import ballerina/sql;
import ballerinax/persist.sql as psql;

isolated psql:DataSourceSpecifics dataspecifics = initializeDataSourceSpecs();

public isolated function initializeDataSourceSpecs() returns psql:DataSourceSpecifics {
    match db_type {
        "mysql" => {
            return psql:MYSQL_SPECIFICS;
        }
        "postgresql" => {
            return psql:POSTGRESQL_SPECIFICS;
        }
        "mssql" => {
            return psql:MSSQL_SPECIFICS;
        }
        "h2" => {
            return psql:H2_SPECIFICS;
        }
        _ => {
            return psql:POSTGRESQL_SPECIFICS;
        }
    }
}

isolated function escape(string value) returns string {
    lock {
        return dataspecifics.quoteOpen + value + dataspecifics.quoteClose;
    }
}

isolated function escapeToQuery(string value) returns sql:ParameterizedQuery {
    lock {
        string escapedValue = escape(value);
        return stringToParameterizedQuery(escapedValue);
    }
}
