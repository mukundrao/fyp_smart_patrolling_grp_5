-- init.sql
CREATE TABLE contacts (
  regno varchar(10) unique not null,
  email varchar(255) not null,
  name text not null default 'anonymous',
  id serial PRIMARY KEY
);

INSERT INTO contacts(regno,email) VALUES
('KA05LN8466','raomukund87@gmail.com'),
('KA02KD2487','raomukund87@gmail.com'),
('KA05LK4727','raomukund87@gmail.com'),
('KA05LP4313','raomukund87@gmail.com'),
('KA05LH8466','raomukund87@gmail.com'),
('KA02JR1207','raomukund87@gmail.com'),
('KA41ER4547','raomukund87@gmail.com'),
('MH04CN5413','raomukund87@gmail.com'),
('MH02BW2586','raomukund87@gmail.com'),
('MH40BW7636','raomukund87@gmail.com'),
('KA02KY9022','raomukund87@gmail.com'),
('KA05JZ5916','raomukund87@gmail.com'),
('UP93AV7286','raomukund87@gmail.com'),
('KA51JF9949','raomukund87@gmail.com'),
('KA02HL9399','raomukund87@gmail.com'),
('KA51HZ0962','raomukund87@gmail.com'),
('KA05LN2421','raomukund87@gmail.com'),
('KA11ER1580','raomukund87@gmail.com'),
('MH09ET9911','raomukund87@gmail.com'),
('KA51EN9804','raomukund87@gmail.com'),
('GJ05TB5347','raomukund87@gmail.com'),
('KA05JL1509','raomukund87@gmail.com'),
('KA02KQ9566','raomukund87@gmail.com'),
('KA51HG5301','raomukund87@gmail.com'),
('KA03KW4456','raomukund87@gmail.com'),
('KA05JZ6978','raomukund87@gmail.com'),
('KA50EB3343','raomukund87@gmail.com'),
('KA05LT4292','raomukund87@gmail.com'),
('KA41EF1078','raomukund87@gmail.com'),
('KA05LQ1574','raomukund87@gmail.com'),
('KA05LT7547','raomukund87@gmail.com'),
('KA05LH4152','raomukund87@gmail.com'),
('KA02KG7344','raomukund87@gmail.com'),
('MH03DZ7902','raomukund87@gmail.com'),
('KA44EB6030','raomukund87@gmail.com');

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