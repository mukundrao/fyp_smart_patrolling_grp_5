-- init.sql
CREATE TABLE contacts (
  regno varchar(10) unique not null,
  email varchar(255) not null,
  name text not null default 'anonymous',
  id serial PRIMARY KEY
);

INSERT INTO contacts(regno,email) VALUES
('<VEHICLE_REGISTRATION_NUMBER>','<EMAIL_ID>');


CREATE TABLE violations (
  id SERIAL PRIMARY KEY,
  regno varchar(10) NOT NULL,
  date DATE DEFAULT CURRENT_DATE,
  lat DECIMAL(6,4) NOT NULL CHECK (lat BETWEEN -90.0000 AND 90.0000),
  long DECIMAL(7,4) NOT NULL CHECK (long BETWEEN -180.0000 AND 180.0000),
  violation_image bytea NOT NULL
);

create table fines(id serial,violation_category text primary key,fine_amount bigint);
insert into fines(violation_category,fine_amount) values ('no-parking',1000);