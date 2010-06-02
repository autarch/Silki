ALTER TABLE "File"
  ADD COLUMN page_id  INT8  NULL;

UPDATE "File"
   SET page_id =
       ( SELECT page_id
           FROM "PageFileLink"
          WHERE "PageFileLink".file_id = "File".file_id );

UPDATE "File"
   SET page_id =
       ( SELECT page_id
           FROM "Page"
          WHERE "Page".wiki_id = "File".wiki_id
            AND "Page".title = 'Front Page' )
 WHERE page_id IS NULL;

ALTER TABLE "File"
  ALTER COLUMN page_id  SET NOT NULL;

ALTER TABLE "File"
  DROP COLUMN wiki_id;

ALTER TABLE "File" ADD CONSTRAINT "File_page_id"
  FOREIGN KEY ("page_id") REFERENCES "Page" ("page_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

DROP TABLE "PageFileLink";
