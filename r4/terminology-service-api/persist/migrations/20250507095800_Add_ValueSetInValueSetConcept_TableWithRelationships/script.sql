-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.


CREATE TABLE `valueset_in_valueset_concepts` (
	`valueSetInValueSetConceptId` INT AUTO_INCREMENT,
	`valuesetconceptValueSetConceptId` INT NOT NULL,
	FOREIGN KEY(`valuesetconceptValueSetConceptId`) REFERENCES `valueset_concepts`(`valueSetConceptId`),
	`valuesetValueSetId` INT NOT NULL,
	FOREIGN KEY(`valuesetValueSetId`) REFERENCES `valuesets`(`valueSetId`),
	PRIMARY KEY(`valueSetInValueSetConceptId`)
);

ALTER TABLE valueset_concepts
MODIFY COLUMN concept LONGBLOB;

