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
       display_name             VARCHAR(255)    NOT NULL DEFAULT '',
       -- SHA512 in Base64 encoding
       password                 VARCHAR(86)     NOT NULL,
       is_admin                 BOOLEAN         NOT NULL DEFAULT FALSE,
       is_system_user           BOOLEAN         NOT NULL DEFAULT FALSE,
       creation_datetime        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
       timezone                 VARCHAR(50)     NOT NULL DEFAULT 'UTC',
       date_format              VARCHAR(12)     NOT NULL DEFAULT '%m/%d/%Y',
       time_format              VARCHAR(12)     NOT NULL DEFAULT '%I:%M %P',
       created_by_user_id       INT8            NULL,
       CONSTRAINT valid_password CHECK ( password != '' )
);

CREATE DOMAIN uri_path_piece AS VARCHAR(255)
       CONSTRAINT valid_uri_path_piece CHECK ( VALUE ~ E'^[a-zA-Z0-9_\-]+$' );

CREATE TABLE "Wiki" (
       wiki_id                  SERIAL8         PRIMARY KEY,
       title                    VARCHAR(255)    NOT NULL,
       -- This will be used in a URI path (/short-name/page/SomePage)
       -- or as a hostname prefix (short-name.wiki.example.com)
       short_name               uri_path_piece  NOT NULL,
       domain_id                INT8            NOT NULL,
       locale_code              VARCHAR(10)     NOT NULL DEFAULT 'en_US',
       email_addresses_are_hidden               BOOLEAN    DEFAULT TRUE,
       user_id                  INT8            NULL,
       CONSTRAINT valid_title CHECK ( title != '' )
);

CREATE DOMAIN hostname AS VARCHAR(255)
       CONSTRAINT valid_hostname CHECK ( VALUE ~ E'^[^\\.]+(?:\\.[^\\.]+)+$' );

CREATE TABLE "Domain" (
       domain_id                SERIAL8         PRIMARY KEY,
       hostname                 hostname        NOT NULL,
       -- It'd be nice to have a domain for this too
       path_prefix              VARCHAR(255)    NOT NULL DEFAULT '',
       requires_ssl             BOOLEAN         NOT NULL DEFAULT FALSE
);

CREATE TABLE "Locale" (
       locale_code              VARCHAR(10)     PRIMARY KEY
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
       is_archived              BOOLEAN         NOT NULL DEFAULT FALSE,
       wiki_id                  INT8            NOT NULL,
       user_id                  INT8            NOT NULL
);

CREATE TABLE "PageRevision" (
       page_id                  INT8            NOT NULL,
       revision_number          INTEGER         NOT NULL,
       title                    VARCHAR(255)    NOT NULL,
       content                  TEXT            NOT NULL,
       user_id                  INT8            NOT NULL,
       creation_datetime        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
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

CREATE TABLE "Tag" (
       tag_id                   SERIAL8         PRIMARY KEY,
       tag                      VARCHAR(200)    NOT NULL,
       CONSTRAINT valid_tag CHECK ( tag != '' )
);

CREATE TABLE "PageFile" (
       page_id                  INT8            NOT NULL,
       file_id                  INT8            NOT NULL,
       PRIMARY KEY ( page_id, file_id )
);

CREATE TABLE "Comment" (
       comment_id               SERIAL8         PRIMARY KEY,
       page_id                  INT8            NOT NULL,
       user_id                  INT8            NOT NULL,
       revision_number          INTEGER         NOT NULL,
       title                    VARCHAR(255)    NOT NULL,
       body                     TEXT            NOT NULL,
       creation_datetime        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
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

CREATE DOMAIN file_name AS VARCHAR(255)
       CONSTRAINT no_slashes CHECK ( VALUE ~ E'^[^\\\\/]+$' );

CREATE TABLE "File" (
       file_id                  SERIAL8         PRIMARY KEY,
       file_name                file_name       NOT NULL,
       mime_type                VARCHAR(255)    NOT NULL,
       file_size                INTEGER         NOT NULL,
       creation_datetime        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_file_name CHECK ( file_name != '' ),
       CONSTRAINT valid_file_size CHECK ( file_size > 0 )
);

-- another cache
CREATE TABLE "FileLink" (
       page_id                  INT8            NOT NULL,
       file_id                  INT8            NOT NULL,
       PRIMARY KEY ( page_id, file_id )
);


ALTER TABLE "User" ADD CONSTRAINT "User_created_by_user_id"
  FOREIGN KEY ("created_by_user_id") REFERENCES "User" ("user_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Wiki" ADD CONSTRAINT "Wiki_domain_id"
  FOREIGN KEY ("domain_id") REFERENCES "Domain" ("domain_id")
  ON DELETE SET DEFAULT ON UPDATE CASCADE;

ALTER TABLE "Wiki" ADD CONSTRAINT "Wiki_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "UserWikiRole" ADD CONSTRAINT "UserWikiRole_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "UserWikiRole" ADD CONSTRAINT "UserWikiRole_wiki_id"
  FOREIGN KEY ("wiki_id") REFERENCES "Wiki" ("wiki_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "UserWikiRole" ADD CONSTRAINT "UserWikiRole_role_id"
  FOREIGN KEY ("role_id") REFERENCES "Role" ("role_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "WikiRolePermission" ADD CONSTRAINT "WikiRolePermission_wiki_id"
  FOREIGN KEY ("wiki_id") REFERENCES "Wiki" ("wiki_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "WikiRolePermission" ADD CONSTRAINT "WikiRolePermission_role_id"
  FOREIGN KEY ("role_id") REFERENCES "Role" ("role_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "WikiRolePermission" ADD CONSTRAINT "WikiRolePermission_permission_id"
  FOREIGN KEY ("permission_id") REFERENCES "Permission" ("permission_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Page" ADD CONSTRAINT "Page_wiki_id"
  FOREIGN KEY ("wiki_id") REFERENCES "Wiki" ("wiki_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Page" ADD CONSTRAINT "Page_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageRevision" ADD CONSTRAINT "PageRevision_page_id"
  FOREIGN KEY ("page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageRevision" ADD CONSTRAINT "PageRevision_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageRevisionTag" ADD CONSTRAINT "PageRevisionTag_page_id_revision_number"
  FOREIGN KEY ("page_id", "revision_number") REFERENCES "PageRevision" ("page_id", "revision_number")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageRevisionTag" ADD CONSTRAINT "PageRevisionTag_tag_id"
  FOREIGN KEY ("tag_id") REFERENCES "Tag" ("tag_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageFile" ADD CONSTRAINT "PageFile_page_id"
  FOREIGN KEY ("page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageFile" ADD CONSTRAINT "PageFile_file_id"
  FOREIGN KEY ("file_id") REFERENCES "File" ("file_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Comment" ADD CONSTRAINT "Page_page_id"
  FOREIGN KEY ("page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Comment" ADD CONSTRAINT "Comment_page_id_revision_number"
  FOREIGN KEY ("page_id", "revision_number") REFERENCES "PageRevision" ("page_id", "revision_number")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageLink" ADD CONSTRAINT "PageLink_from_page_id"
  FOREIGN KEY ("from_page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PageLink" ADD CONSTRAINT "PageLink_to_page_id"
  FOREIGN KEY ("to_page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "FileLink" ADD CONSTRAINT "FileLink_page_id"
  FOREIGN KEY ("page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "FileLink" ADD CONSTRAINT "FileLink_file_id"
  FOREIGN KEY ("file_id") REFERENCES "File" ("file_id")
  ON DELETE CASCADE ON UPDATE CASCADE;
