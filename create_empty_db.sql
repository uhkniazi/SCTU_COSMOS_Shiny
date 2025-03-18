CREATE DATABASE  IF NOT EXISTS `COSMOS_Shiny_demo` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `COSMOS_Shiny_demo`;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `clinicaldata`
--

DROP TABLE IF EXISTS `clinicaldata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `clinicaldata` (
  `idClinicalData` int NOT NULL AUTO_INCREMENT,
  `Type` varchar(255) NOT NULL,
  `Value` varchar(255) DEFAULT NULL,
  `Subject_idUnit` int NOT NULL,
  `Study_idStudy` int NOT NULL,
  `Description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`idClinicalData`),
  UNIQUE KEY `idClinicalData_UNIQUE` (`idClinicalData`),
  KEY `fk_ClinicalData_Subject1_idx` (`Subject_idUnit`),
  KEY `fk_ClinicalData_Study1_idx` (`Study_idStudy`),
  CONSTRAINT `fk_ClinicalData_Study1` FOREIGN KEY (`Study_idStudy`) REFERENCES `study` (`idStudy`),
  CONSTRAINT `fk_ClinicalData_Subject1` FOREIGN KEY (`Subject_idUnit`) REFERENCES `subject` (`idUnit`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Table to hold all clinical and demographic data and any metadata related to a unit of analysis';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `datalevel0`
--

DROP TABLE IF EXISTS `datalevel0`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `datalevel0` (
  `idDataLevel0` int NOT NULL AUTO_INCREMENT,
  `Sample_idSample` int NOT NULL,
  `FileName` text NOT NULL,
  `Type` varchar(45) NOT NULL,
  `Location` text NOT NULL,
  PRIMARY KEY (`idDataLevel0`),
  UNIQUE KEY `idDataLevel0_UNIQUE` (`idDataLevel0`),
  KEY `fk_DataLevel0_Sample1_idx` (`Sample_idSample`),
  CONSTRAINT `fk_DataLevel0_Sample1` FOREIGN KEY (`Sample_idSample`) REFERENCES `omicssample` (`idOmicsSample`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Each Sample has an associated raw data file or more than one e.g. a RNA-Seq sample will have two FASTQ files';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `datalevel1`
--

DROP TABLE IF EXISTS `datalevel1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `datalevel1` (
  `idDataLevel1` int NOT NULL AUTO_INCREMENT,
  `Dataset_idDataset` int NOT NULL,
  `FileName` text NOT NULL,
  `Type` varchar(45) NOT NULL COMMENT 'short description of file type e.g. vcf, count matrix etc.',
  `Location` text NOT NULL COMMENT 'folder path where it is saved',
  `ProcessingSteps` text COMMENT 'how was this file generated, any comments or git repository link',
  PRIMARY KEY (`idDataLevel1`),
  UNIQUE KEY `idDataLevel1_UNIQUE` (`idDataLevel1`),
  KEY `fk_DataLevel1_Dataset1_idx` (`Dataset_idDataset`),
  CONSTRAINT `fk_DataLevel1_Dataset1` FOREIGN KEY (`Dataset_idDataset`) REFERENCES `dataset` (`idDataset`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='This contains the processed data in a self contained format e.g. the count matrix with associated metadata all in the form of a R or SAS etc object. This is analysis ready data.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dataset`
--

DROP TABLE IF EXISTS `dataset`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dataset` (
  `idDataset` int NOT NULL AUTO_INCREMENT,
  `Study_idStudy` int NOT NULL,
  `OmicsDataType` varchar(255) NOT NULL,
  `Tissue` varchar(45) DEFAULT NULL,
  `Git` text,
  `Date` date DEFAULT NULL,
  `Instrument` varchar(255) DEFAULT NULL,
  `ProcessingSteps` text,
  PRIMARY KEY (`idDataset`),
  UNIQUE KEY `idDataset_UNIQUE` (`idDataset`),
  KEY `fk_Dataset_Study1_idx` (`Study_idStudy`),
  CONSTRAINT `fk_Dataset_Study1` FOREIGN KEY (`Study_idStudy`) REFERENCES `study` (`idStudy`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Each study can have multiple omics data sets and related information will go here';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `omicssample`
--

DROP TABLE IF EXISTS `omicssample`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `omicssample` (
  `idOmicsSample` int NOT NULL AUTO_INCREMENT COMMENT 'each sample belongs to one unit of analysis',
  `Dataset_idDataset` int NOT NULL,
  `Subject_idUnit` int NOT NULL,
  PRIMARY KEY (`idOmicsSample`),
  UNIQUE KEY `idSample_UNIQUE` (`idOmicsSample`),
  KEY `fk_Sample_Dataset1_idx` (`Dataset_idDataset`),
  KEY `fk_Sample_Subject1_idx` (`Subject_idUnit`),
  CONSTRAINT `fk_Sample_Dataset1` FOREIGN KEY (`Dataset_idDataset`) REFERENCES `dataset` (`idDataset`),
  CONSTRAINT `fk_Sample_Subject1` FOREIGN KEY (`Subject_idUnit`) REFERENCES `subject` (`idUnit`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Each Omics Sample belongs to a dataset. It also belongs to a unit of analysis i.e. Subject_idUnit. One unit of analysis can have multiple samples if technical replicates were produced i.e. a biological sample from a subject sequenced multiple times.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `omicssamplemetadata`
--

DROP TABLE IF EXISTS `omicssamplemetadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `omicssamplemetadata` (
  `idOmicsSampleMetaData` int NOT NULL AUTO_INCREMENT,
  `Type` varchar(255) NOT NULL,
  `Value` varchar(255) DEFAULT NULL,
  `OmicsSample_idOmicsSample` int NOT NULL,
  `Description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`idOmicsSampleMetaData`),
  UNIQUE KEY `id_UNIQUE` (`idOmicsSampleMetaData`),
  KEY `fk_MetadataSample_Sample1_idx` (`OmicsSample_idOmicsSample`),
  CONSTRAINT `fk_MetadataSample_Sample1` FOREIGN KEY (`OmicsSample_idOmicsSample`) REFERENCES `omicssample` (`idOmicsSample`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='The metadata related to the omics sample. this usually will be the lab associated additional information e.g. Sequencing lanes, batches, RNA-quality etc';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `results`
--

DROP TABLE IF EXISTS `results`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `results` (
  `idResults` int NOT NULL AUTO_INCREMENT,
  `Study_idStudy` int NOT NULL,
  `Dataset_idDataset` int DEFAULT NULL COMMENT 'this can be null as a result may not be linked to a single data set directly and can be more general',
  `Location` text COMMENT 'a folder path where the result file is stored',
  `FileName` text,
  `Git` text COMMENT 'any further information that may need to be added related to the results on the associated github repository',
  `ProcessingSteps` text,
  PRIMARY KEY (`idResults`),
  UNIQUE KEY `idResults_UNIQUE` (`idResults`),
  KEY `fk_Results_Study1_idx` (`Study_idStudy`),
  KEY `fk_Results_Dataset1_idx` (`Dataset_idDataset`),
  CONSTRAINT `fk_Results_Dataset1` FOREIGN KEY (`Dataset_idDataset`) REFERENCES `dataset` (`idDataset`),
  CONSTRAINT `fk_Results_Study1` FOREIGN KEY (`Study_idStudy`) REFERENCES `study` (`idStudy`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Results table with links to figures, reports excel sheets and misc';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `study`
--

DROP TABLE IF EXISTS `study`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `study` (
  `idStudy` int NOT NULL AUTO_INCREMENT,
  `StudyName` varchar(45) NOT NULL,
  `Disease` varchar(45) DEFAULT NULL,
  `Treatment` varchar(255) DEFAULT NULL,
  `Funder` varchar(45) DEFAULT NULL,
  `Status` varchar(45) DEFAULT NULL,
  `Abstract` text,
  `Git` text,
  `Date` date DEFAULT NULL,
  `Documents_location` text,
  PRIMARY KEY (`idStudy`),
  UNIQUE KEY `idStudy_UNIQUE` (`idStudy`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='This is the main table of the database holding information about a study and other associated information relevant here.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `studysampletype`
--

DROP TABLE IF EXISTS `studysampletype`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `studysampletype` (
  `idStudySampleType` int NOT NULL AUTO_INCREMENT,
  `Type` varchar(255) DEFAULT NULL,
  `TranslationalWork` text,
  `Study_idStudy` int NOT NULL,
  PRIMARY KEY (`idStudySampleType`),
  UNIQUE KEY `id_UNIQUE` (`idStudySampleType`),
  KEY `fk_StudySampleType_Study_idx` (`Study_idStudy`),
  CONSTRAINT `fk_StudySampleType_Study` FOREIGN KEY (`Study_idStudy`) REFERENCES `study` (`idStudy`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='This table contains additional information about the type of translational data e.g. a study can collect multiple types of data and some general information can be held in this table';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subject`
--

DROP TABLE IF EXISTS `subject`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subject` (
  `idUnit` int NOT NULL AUTO_INCREMENT COMMENT 'a unit of analysis - it is typically a combination of subject id, and visit for each study',
  `idAnonymised` int NOT NULL COMMENT 'anonymised database id from external source',
  `Visit` int NOT NULL COMMENT 'visit number ',
  `Study_idStudy` int NOT NULL,
  PRIMARY KEY (`idUnit`),
  UNIQUE KEY `uc_idAnonymised_Visit_idStudy` (`idAnonymised`,`Visit`,`Study_idStudy`),
  UNIQUE KEY `idUnit_UNIQUE` (`idUnit`),
  KEY `fk_Subject_Study1_idx` (`Study_idStudy`) /*!80000 INVISIBLE */,
  CONSTRAINT `fk_Subject_Study1` FOREIGN KEY (`Study_idStudy`) REFERENCES `study` (`idStudy`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='This table will contain information about each unit of analysis. Typically this will be a combination of subject id and the visit number.';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
