-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

DROP TABLE valueset_compose_include_code_systems;

ALTER TABLE valueset_compose_includes
ADD COLUMN codeSystemId INT;

