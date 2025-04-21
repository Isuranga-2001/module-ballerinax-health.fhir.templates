-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

ALTER TABLE valuesets
MODIFY COLUMN title VARCHAR(191) NOT NULL;

ALTER TABLE valuesets
MODIFY COLUMN date VARCHAR(191) NOT NULL;

ALTER TABLE valuesets
MODIFY COLUMN publisher VARCHAR(191) NOT NULL;

ALTER TABLE valuesets
MODIFY COLUMN description VARCHAR(191) NOT NULL;

ALTER TABLE codesystems
MODIFY COLUMN title VARCHAR(191) NOT NULL;

ALTER TABLE codesystems
MODIFY COLUMN date VARCHAR(191) NOT NULL;

ALTER TABLE codesystems
MODIFY COLUMN publisher VARCHAR(191) NOT NULL;

