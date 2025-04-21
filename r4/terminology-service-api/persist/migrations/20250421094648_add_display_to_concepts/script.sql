-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

ALTER TABLE concepts
ADD COLUMN display VARCHAR(191) NOT NULL;

ALTER TABLE concepts
ADD COLUMN definition VARCHAR(191) NOT NULL;

