-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

ALTER TABLE concepts
DROP COLUMN display;

ALTER TABLE concepts
DROP COLUMN definition;


CREATE TABLE `valueset_concepts` (
	`valueSetConceptId` INT AUTO_INCREMENT,
	`system` VARCHAR(191),
	`version` VARCHAR(191),
	`code` VARCHAR(191),
	`concept` LONGBLOB NOT NULL,
	`valuesetValueSetId` INT NOT NULL,
	FOREIGN KEY(`valuesetValueSetId`) REFERENCES `valuesets`(`valueSetId`),
	PRIMARY KEY(`valueSetConceptId`)
);

ALTER TABLE concepts
ADD COLUMN parentConceptId INT;

