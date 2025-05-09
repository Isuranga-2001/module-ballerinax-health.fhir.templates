-- AUTO-GENERATED FILE.
-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

DROP TABLE valueset_concepts;

DROP TABLE valueset_in_valueset_concepts;


CREATE TABLE `valueset_compose_includes` (
	`valueSetComposeIncludeId` INT AUTO_INCREMENT,
	`systemFlag` BOOLEAN NOT NULL,
	`valueSetFlag` BOOLEAN NOT NULL,
	`conceptFlag` BOOLEAN NOT NULL,
	`valuesetValueSetId` INT NOT NULL,
	FOREIGN KEY(`valuesetValueSetId`) REFERENCES `valuesets`(`valueSetId`),
	PRIMARY KEY(`valueSetComposeIncludeId`)
);


CREATE TABLE `valueset_compose_include_value_sets` (
	`valueSetComposeIncludeValueSetId` INT AUTO_INCREMENT,
	`valuesetcomposeValueSetComposeIncludeId` INT NOT NULL,
	FOREIGN KEY(`valuesetcomposeValueSetComposeIncludeId`) REFERENCES `valueset_compose_includes`(`valueSetComposeIncludeId`),
	`valuesetValueSetId` INT NOT NULL,
	FOREIGN KEY(`valuesetValueSetId`) REFERENCES `valuesets`(`valueSetId`),
	PRIMARY KEY(`valueSetComposeIncludeValueSetId`)
);


CREATE TABLE `valueset_compose_include_code_systems` (
	`valueSetComposeIncludeCodeSystemId` INT AUTO_INCREMENT,
	`valuesetcomposeValueSetComposeIncludeId` INT NOT NULL,
	FOREIGN KEY(`valuesetcomposeValueSetComposeIncludeId`) REFERENCES `valueset_compose_includes`(`valueSetComposeIncludeId`),
	`codesystemCodeSystemId` INT NOT NULL,
	FOREIGN KEY(`codesystemCodeSystemId`) REFERENCES `codesystems`(`codeSystemId`),
	PRIMARY KEY(`valueSetComposeIncludeCodeSystemId`)
);


CREATE TABLE `valueset_compose_include_concepts` (
	`valueSetComposeIncludeConceptId` INT AUTO_INCREMENT,
	`valuesetcomposeValueSetComposeIncludeId` INT NOT NULL,
	FOREIGN KEY(`valuesetcomposeValueSetComposeIncludeId`) REFERENCES `valueset_compose_includes`(`valueSetComposeIncludeId`),
	`conceptConceptId` INT NOT NULL,
	FOREIGN KEY(`conceptConceptId`) REFERENCES `concepts`(`conceptId`),
	PRIMARY KEY(`valueSetComposeIncludeConceptId`)
);

