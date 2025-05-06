-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

ALTER TABLE valueset_concepts
ADD COLUMN systemFlag BOOLEAN NOT NULL;

