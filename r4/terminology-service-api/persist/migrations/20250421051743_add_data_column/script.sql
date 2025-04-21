-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

ALTER TABLE concepts
ADD COLUMN concept LONGBLOB NOT NULL;

ALTER TABLE valuesets
ADD COLUMN valueSet LONGBLOB NOT NULL;

ALTER TABLE codesystems
ADD COLUMN codeSystem LONGBLOB NOT NULL;

