SET CLIENT_MIN_MESSAGES = ERROR;

DROP DATABASE IF EXISTS "Silk";

CREATE DATABASE "Silk"
       ENCODING = 'UTF8';

\connect "Silk"

SET CLIENT_MIN_MESSAGES = ERROR;

CREATE DOMAIN email_address AS VARCHAR(255)
       CONSTRAINT valid_email_address CHECK ( VALUE ~ E'^.+@.+(?:\\..+)+' );

CREATE TABLE "User" (
       user_id                  SERIAL8         PRIMARY KEY,
       email_address            email_address   UNIQUE  NOT NULL,
       -- username is here primarily so we can uniquely identify
       -- system-created users even when the system's hostname
       -- changes, for normal users it can just be their email address
       username                 VARCHAR(255)    UNIQUE  NOT NULL,
       real_name                VARCHAR(255)    DEFAULT '',
       -- SHA512 in Base64 encoding
       password                 VARCHAR(86)     NOT NULL,
       is_admin                 BOOLEAN         DEFAULT FALSE,
       is_system_user           BOOLEAN         DEFAULT FALSE,
       creation_datetime        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       created_by_user_id       INT8            NULL,
       CONSTRAINT valid_password CHECK ( password != '' )
);

CREATE TABLE "Wiki" (
       wiki_id                  SERIAL8         PRIMARY KEY,
       title                    VARCHAR(255)    NOT NULL,
       domain_id                INT8            NOT NULL,
       locale_code              VARCHAR(10)     NOT NULL,
       CONSTRAINT valid_title CHECK ( title != '' )
);

CREATE DOMAIN hostname AS VARCHAR(255)
       CONSTRAINT valid_hostname CHECK ( VALUE ~ E'^[^\\.]+(?:\\.[^\\.]+)+$' );

CREATE TABLE "Domain" (
       domain_id                SERIAL8         PRIMARY KEY,
       hostname                 hostname        NOT NULL,
       requires_ssl             BOOLEAN         DEFAULT FALSE
);

CREATE TABLE "Locale" (
       locale_code              VARCHAR(10)     PRIMARY KEY,
);

CREATE TABLE "Role" (
       role_id                  SERIAL8         PRIMARY KEY,
       name                     VARCHAR(50)     NOT NULL
);

CREATE TABLE "Permission" (
       permission_id            SERIAL8         PRIMARY KEY,
       name                     VARCHAR(50)     NOT NULL
);

CREATE TABLE "UserWikiRole" (
       user_id                  INT8            NOT NULL,
       wiki_id                  INT8            NOT NULL,
       role_id                  INT8            NOT NULL,
       PRIMARY KEY ( user_id, wiki_id, role_id )
);

CREATE TABLE "WikiRolePermission" (
       wiki_id                  INT8            NOT NULL,
       role_id                  INT8            NOT NULL,
       permission_id            INT8            NOT NULL,
       PRIMARY KEY ( wiki_id, role_id, permission_id )
);

CREATE TABLE "Page" (
       page_id                  SERIAL8         PRIMARY KEY,
       is_deleted               BOOLEAN         DEFAULT FALSE
);

CREATE TABLE "PageRevision" (
       page_id                  INT8            NOT NULL,
       revision_number          INTEGER         NOT NULL,
       title                    VARCHAR(255)    NOT NULL,
       content                  TEXT            NOT NULL,
       creator_user_id          INT8            NOT NULL,
       creation_datetime        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       is_deleted               BOOLEAN         DEFAULT 'n',
       is_restoration_of_revision_number        INTEGER         NULL,
       PRIMARY KEY ( page_id, revision_number ),
       CONSTRAINT valid_revision_number CHECK ( revision_number > 0 ),
       CONSTRAINT valid_title CHECK ( title != '' )
);

CREATE TABLE "PageRevisionTag" (
       page_id                  INT8            NOT NULL,
       revision_number          INTEGER         NOT NULL,
       tag_id                   INT8            NOT NULL,
       PRIMARY KEY ( page_id, revision_number, tag_id )
);

CREATE TABLE "PageFile" (
       page_id                  INT8            NOT NULL,
       file_id                  INT8            NOT NULL,
       PRIMARY KEY ( page_id, file_id )
);

CREATE TABLE "PageComment" (
       comment_id               SERIAL8         PRIMARY KEY,
       page_id                  INT8            NOT NULL,
       revision_number          INTEGER         NOT NULL,
       title                    VARCHAR(255)    NOT NULL,
       body                     TEXT            NOT NULL,
       parent_comment_id        INT8            NULL,
       creation_datetime        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_title CHECK ( body != '' )
);

-- This is a cache, since the same information could be retrieved by
-- looking at the latest revision content for each page as
-- needed. Obviously, that would be prohibitively expensive.
CREATE TABLE "PageLink" (
       from_page_id             INT8            NOT NULL,
       to_page_id               INT8            NOT NULL,
       PRIMARY KEY ( from_page_id, to_page_id )
);

CREATE TABLE "Tag" (
       tag_id                   SERIAL8         PRIMARY KEY,
       tag                      VARCHAR(200)    NOT NULL,
       CONSTRAINT valid_tag CHECK ( tag != '' )
);

CREATE DOMAIN file_name AS VARCHAR(255)
       CONSTRAINT no_slashes CHECK ( VALUE ~ E'^[^\\\\/]+$' );

CREATE TABLE "File" (
       file_id                  SERIAL8         PRIMARY KEY,
       file_name                file_name       NOT NULL,
       mime_type                VARCHAR(255)    NOT NULL,
       file_size                INTEGER         NOT NULL,
       creation_datetime        TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_file_name CHECK ( file_name != '' ),
       CONSTRAINT valid_file_size CHECK ( file_size > 0 )
);

-- Need some foreign keys, yo
