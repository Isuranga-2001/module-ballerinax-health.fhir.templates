-- AUTO-GENERATED FILE.

-- This file is an auto-generated file by Ballerina persistence layer for the migrate command.
-- Please verify the generated scripts and execute them against the target DB server.

DROP TABLE IF EXISTS `concepts`;
DROP TABLE IF EXISTS `valuesets`;
DROP TABLE IF EXISTS `codesystems`;

CREATE TABLE `codesystems` (
	`codeSystemId` INT AUTO_INCREMENT,
	`id` VARCHAR(191) NOT NULL,
	`url` VARCHAR(191) NOT NULL,
	`version` VARCHAR(191) NOT NULL,
	`name` VARCHAR(191) NOT NULL,
	`title` VARCHAR(191),
	`status` VARCHAR(191) NOT NULL,
	`date` DATE,
	`publisher` VARCHAR(191),
	PRIMARY KEY(`codeSystemId`)
);

CREATE TABLE `valuesets` (
	`valueSetId` INT AUTO_INCREMENT,
	`id` VARCHAR(191) NOT NULL,
	`url` VARCHAR(191) NOT NULL,
	`version` VARCHAR(191) NOT NULL,
	`name` VARCHAR(191) NOT NULL,
	`title` VARCHAR(191),
	`status` VARCHAR(191) NOT NULL,
	`date` DATE,
	`publisher` VARCHAR(191),
	`description` VARCHAR(191),
	PRIMARY KEY(`valueSetId`)
);

CREATE TABLE `concepts` (
	`conceptId` INT AUTO_INCREMENT,
	`code` VARCHAR(191) NOT NULL,
	`codesystemCodeSystemId` INT NOT NULL,
	FOREIGN KEY(`codesystemCodeSystemId`) REFERENCES `codesystems`(`codeSystemId`),
	PRIMARY KEY(`conceptId`)
);


