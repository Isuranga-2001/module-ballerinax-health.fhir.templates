
import ballerina/sql;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.terminology;

public type SQLDialect "postgresql"|"mysql"|"mssql";

public type SQLQueryBuilder object {
    public function buildWhereClause(map<r4:RequestSearchParameter[]> params) returns sql:ParameterizedQuery;
};

class SQLBuilderFactory {
    public isolated function getBuilder(SQLDialect dialect) returns SQLQueryBuilder|error {
        match dialect {
            "postgresql" => {
                return new PostgreSQLQueryBuilder();
            }
            "mysql" => {
                return new MySQLQueryBuilder();
            }
            "mssql" => {
                return new MSSQLQueryBuilder();
            }
        }

        return error("Unsupported SQL dialect");
    }
}

class PostgreSQLQueryBuilder {
    *SQLQueryBuilder;

    public function buildWhereClause(map<r4:RequestSearchParameter[]> params) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery[] fragments = [];

        foreach var [paramName, paramList] in params.entries() {
            if terminology:CODESYSTEMS_SEARCH_PARAMS.hasKey(paramName) {
                foreach var param in paramList {
                    if fragments.length() > 0 {
                        fragments.push(` AND `);
                    }

                    string column = terminology:CODESYSTEMS_SEARCH_PARAMS.get(paramName);
                    if column == "name" || column == "title" {
                        fragments.push(`"${column}" ILIKE ${param.value}`);
                    } else {
                        fragments.push(`"${column}" = ${param.value}`);
                    }
                }
            }
        }

        return fragments.length() > 0 ? sql:queryConcat(...fragments) : ``;
    }
}

class MySQLQueryBuilder {
    *SQLQueryBuilder;

    public function buildWhereClause(map<r4:RequestSearchParameter[]> params) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery[] fragments = [];

        foreach var [paramName, paramList] in params.entries() {
            if terminology:CODESYSTEMS_SEARCH_PARAMS.hasKey(paramName) {
                foreach var param in paramList {
                    if fragments.length() > 0 {
                        fragments.push(` AND `);
                    }

                    string column = terminology:CODESYSTEMS_SEARCH_PARAMS.get(paramName);
                    if column == "name" || column == "title" {
                        fragments.push(sql:queryConcat(`${column}`, ` LIKE ${param.value}`));
                    } else {
                        fragments.push(sql:queryConcat(`${column}`, ` = ${param.value}`));
                    }
                }
            }
        }

        return fragments.length() > 0 ? sql:queryConcat(...fragments) : ``;
    }
}

class MSSQLQueryBuilder {
    *SQLQueryBuilder;

    public function buildWhereClause(map<r4:RequestSearchParameter[]> params) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery[] fragments = [];

        foreach var [paramName, paramList] in params.entries() {
            if terminology:CODESYSTEMS_SEARCH_PARAMS.hasKey(paramName) {
                foreach var param in paramList {
                    if fragments.length() > 0 {
                        fragments.push(` AND `);
                    }

                    string column = terminology:CODESYSTEMS_SEARCH_PARAMS.get(paramName);
                    if column == "name" || column == "title" {
                        fragments.push(`[${column}] LIKE ${param.value}`);
                    } else {
                        fragments.push(`[${column}] = ${param.value}`);
                    }
                }
            }
        }

        return fragments.length() > 0 ? sql:queryConcat(...fragments) : ``;
    }
}
