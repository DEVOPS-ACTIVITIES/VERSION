DROP SCHEMA IF EXISTS infra CASCADE ; 

CREATE SCHEMA IF NOT EXISTS infra;

CREATE SEQUENCE infra.project_code_seq START 1;


CREATE TABLE IF NOT EXISTS  infra.project (
  project_code character varying(10) DEFAULT ('PS'::text || lpad((nextval('infra.project_code_seq'::regclass))::text, 3, '0'::text)) NOT NULL,
  project character varying(100) NOT NULL,
  created_by character varying(20),
  created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_by character varying(20),
  updated_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  description text,
  is_deleted bool DEFAULT false,
  status bool DEFAULT true
);

ALTER TABLE infra.project ADD CONSTRAINT project_pkey PRIMARY KEY (project_code);


INSERT INTO infra.project (project, description) VALUES ('Informatica Migration Project', 'Migrating Informatica Code to the cloud');



CREATE TABLE IF NOT EXISTS  infra.roles (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  role character varying(200),
  description character varying(500),
  created_by character varying(20),
  created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_by character varying(20),
  updated_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE infra.roles ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


INSERT INTO infra.roles (id, role, description) VALUES ('69fd89dc-b2bf-49af-a42b-5ef014c3c484', 'Administrator', 'Has full access to the system');
INSERT INTO infra.roles (id, role, description) VALUES ('136d7ac8-f283-43b7-8e0f-7f7c9e5815f5', 'Developer', 'Has Access to application with minimum rights');



CREATE TABLE IF NOT EXISTS  infra.users (
  user_id character varying(50) NOT NULL,
  full_name character varying(150),
  email_id character varying(255),
  role_id uuid,
  created_by character varying(20),
  created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_by character varying(20),
  updated_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  password_hash character varying(255),
  is_deleted bool DEFAULT false
);

ALTER TABLE infra.users ADD CONSTRAINT user_pk PRIMARY KEY (user_id);
ALTER TABLE infra.users ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES infra.roles(id);


INSERT INTO infra.users (user_id, full_name, email_id, role_id,password_hash) VALUES ('105330', 'Admin', 'Admin@p2x.com','69fd89dc-b2bf-49af-a42b-5ef014c3c484','a61d03bcc494b368e67f63579f67304f890e27f3762dad8797ccd84b4d9b3d45');
INSERT INTO infra.users (user_id, full_name, email_id, role_id,password_hash) VALUES ('105332', 'Admin_new', 'admin_new@p2x.com','69fd89dc-b2bf-49af-a42b-5ef014c3c484','e86f78a8a3caf0b60d8e74e5942aa6d86dc150cd3c03338aef25b7d2d7e3acc7');


CREATE SEQUENCE infra.user_projects_id_seq START 1;


CREATE TABLE IF NOT EXISTS  infra.user_projects (
  id int4 DEFAULT nextval('infra.user_projects_id_seq'::regclass) NOT NULL,
  user_id character varying(50),
  project_code character varying(10),
  is_deleted bool DEFAULT false
);

ALTER TABLE infra.user_projects ADD CONSTRAINT user_projects_pkey PRIMARY KEY (id);
ALTER TABLE infra.user_projects ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES infra.users(user_id);
ALTER TABLE infra.user_projects ADD CONSTRAINT fk_project FOREIGN KEY (project_code) REFERENCES infra.project(project_code);


INSERT INTO infra.user_projects (user_id,project_code) VALUES ('105330','PS001');
INSERT INTO infra.user_projects (user_id,project_code) VALUES ('105332','PS001');


CREATE SEQUENCE infra.access_requests_seq START 1;

CREATE TABLE IF NOT EXISTS  infra.access_requests (
  request_id character varying(15) DEFAULT ('REQ'::text || lpad((nextval('infra.access_requests_seq'::regclass))::text, 4, '0'::text)) NOT NULL,
  full_name character varying(255) NOT NULL,
  email text NOT NULL,
  team_name character varying(255) NOT NULL,
  why_need_access text NOT NULL,
  project_code character varying(10) NOT NULL,
  request_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  status character varying(20) DEFAULT 'pending'::character varying
);

ALTER TABLE infra.access_requests ADD CONSTRAINT access_requests_pkey PRIMARY KEY (request_id);


CREATE TABLE IF NOT EXISTS  infra.models_metadata (
  provider_name character varying(100),
  model_name character varying(100)
);

INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('OpenAI', 'gpt-4o');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('Google', 'gemini-2.0-flash');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('Meta', 'llama-3.2-3b');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('Anthropic', 'claude-3-7-sonnet-latest');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('Anthropic', 'claude-3-opus-latest');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('AzureOpenAI', 'gpt-4.1');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('Databricks', 'databricks-claude-3-7-sonnet');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('AWS Bedrock', 'anthropic.claude-3-sonnet-20240229-v1:0');
INSERT INTO infra.models_metadata (provider_name, model_name) VALUES ('Google Vertex AI', 'gemini-2.0-flash');

CREATE SEQUENCE infra.connection_details_seq START 1;


CREATE TABLE IF NOT EXISTS  infra.connection_details (
  connection_id character varying(10) DEFAULT ('CON'::text || lpad((nextval('infra.connection_details_seq'::regclass))::text, 3, '0'::text)) NOT NULL,
  connection_name character varying(120) NOT NULL,
  db_name character varying(50) NOT NULL,
  database character varying(120) NOT NULL,
  project_code character varying(10),
  created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  requested_by character varying(150) NOT NULL,
  connection_key jsonb NOT NULL,
  connection_test character varying(10) DEFAULT 'pending'::character varying,
  is_deleted bool DEFAULT false,
  region character varying(50)
);

ALTER TABLE infra.connection_details ADD CONSTRAINT connection_details_pkey PRIMARY KEY (connection_id);
ALTER TABLE infra.connection_details ADD CONSTRAINT connection_details_project_code_fkey FOREIGN KEY (project_code) REFERENCES infra.project(project_code);


CREATE TABLE IF NOT EXISTS  infra.job_details (
  run_id character varying(255) NOT NULL,
  xml text,
  user_project_id int4,
  status character varying(255) DEFAULT 'IN PROGRESS'::character varying,
  step character varying(255) DEFAULT 'Parsing'::character varying,
  data_handling character varying(255),
  validation_status character varying(255) DEFAULT 'NA'::character varying,
  xml_type character varying(255),
  workflow_name character varying(255),
  session_name character varying(255),
  mapping_name character varying(255),
  job_metadata jsonb,
  sql_file text,
  total_transformations int4,
  sources int4,
  targets int4,
  total_input_tokens int8,
  total_output_tokens int8,
  total_validation_time text DEFAULT 'NA'::text,
  created_by character varying(255),
  created_on timestamp without time zone,
  updated_by character varying(255),
  updated_on timestamp without time zone,
  is_deleted bool DEFAULT false,
  target_tech character varying(50),
  xml_hash_key varchar,
  reusable_query text,
  is_reusable bool,
  folder_name character varying(100),
  reusable_session_name character varying(100),
  reusable_worklet_name character varying(100),
  visualisation_data jsonb,
  misc_data jsonb,
  schema_details jsonb,
  llm_used character varying(50),
  conn_name character varying(255),
  param_file_name character varying(255),
  mapplet int4,
  unconnected int4,
  transformation int4,
  version int4 NOT NULL,
  reusable_run_id character varying(255),
  topological_sort jsonb,
  xml_file_location character varying(255),
  optimization_query jsonb,
  optimization_status character varying(20),
  generation_error_message text,
  bulk_run_id character varying(255),
  error_message text NULL,
  router_details jsonb NULL,
  synthetic_metadata jsonb DEFAULT '{}'::jsonb NULL,
  synthetic_data_generated bool DEFAULT false NULL,
  source_tables jsonb NULL,
  target_tables jsonb NULL
);

ALTER TABLE infra.job_details ADD CONSTRAINT job_details_user_project_id_fkey FOREIGN KEY (user_project_id) REFERENCES infra.user_projects(id);
ALTER TABLE infra.job_details ADD CONSTRAINT job_details_pkey PRIMARY KEY (run_id, version);



CREATE OR REPLACE FUNCTION infra.get_next_version(run_id_param VARCHAR)
RETURNS INTEGER AS $$
DECLARE 
    next_version INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1
    INTO next_version
    FROM infra.job_details
    WHERE run_id = run_id_param;

    RETURN next_version;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Create trigger function to set version before insert
CREATE OR REPLACE FUNCTION infra.set_version_before_insert()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version := infra.get_next_version(NEW.run_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create trigger on job_details table
CREATE TRIGGER before_insert_set_version
BEFORE INSERT ON infra.job_details
FOR EACH ROW
EXECUTE FUNCTION infra.set_version_before_insert();


CREATE SEQUENCE infra.llm_model_seq START 1;


CREATE TABLE IF NOT EXISTS  infra.llm_models (
  model_id character varying(10) DEFAULT ('LLM'::text || lpad((nextval('infra.llm_model_seq'::regclass))::text, 3, '0'::text)) NOT NULL,
  llm_provider character varying(100),
  model_name character varying(100),
  project_code character varying(10),
  created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  created_by character varying(50),
  updated_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_by character varying(50),
  api_key jsonb,
  api_key_validation character varying(50),
  is_deleted bool DEFAULT false
);

ALTER TABLE infra.llm_models ADD CONSTRAINT llm_models_pkey PRIMARY KEY (model_id);
ALTER TABLE infra.llm_models ADD CONSTRAINT fk_project_code FOREIGN KEY (project_code) REFERENCES infra.project(project_code);


CREATE TABLE IF NOT EXISTS  infra.schema_details (
  run_id character varying(255) NOT NULL,
  con_id character varying(10),
  target_tech character varying(100),
  table_name character varying(255) NOT NULL,
  table_type character varying(100),
  db_name character varying(255),
  schema_name character varying(255),
  created_by character varying(20),
  created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_by character varying(20),
  updated_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE infra.schema_details ADD CONSTRAINT schema_details_pkey PRIMARY KEY (run_id);



CREATE TABLE IF NOT EXISTS  infra.transformation_level_details (
  run_id character varying(255) NOT NULL,
  transformation_name character varying(256) NOT NULL,
  sql_file text,
  iteration int4 NOT NULL,
  status character varying(20),
  transformation_type character varying(50),
  job_metadata jsonb,
  failure_message text,
  input_tokens int8,
  llm_used character varying(60),
  output_tokens int8,
  created_by character varying(20),
  created_on timestamp without time zone,
  updated_by character varying(20),
  updated_on timestamp without time zone
);

ALTER TABLE infra.transformation_level_details ADD CONSTRAINT transformation_level_details_pkey PRIMARY KEY (run_id, iteration, transformation_name);

-- Trigger: before_insert_set_iteration
	
CREATE OR REPLACE FUNCTION infra.get_next_iteration(run_id_param VARCHAR, transformation_name_param VARCHAR)
RETURNS INTEGER AS $$
DECLARE 
    next_iteration INTEGER;
BEGIN
    -- Get the max iteration for the given run_id and transformation_name
    SELECT COALESCE(MAX(iteration), 0) + 1 
    INTO next_iteration
    FROM infra.Transformation_Level_Details
    WHERE run_id = run_id_param
    AND transformation_name = transformation_name_param;

    RETURN next_iteration;
END;
$$ LANGUAGE plpgsql;


-- Create Trigger Function to Set iteration Before Insert
CREATE OR REPLACE FUNCTION infra.set_iteration_before_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Automatically set iteration before inserting a new row
    NEW.iteration := infra.get_next_iteration(NEW.run_id, NEW.transformation_name);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a Trigger to Execute the Function

CREATE TRIGGER before_insert_set_iteration
BEFORE INSERT ON infra.Transformation_Level_Details
FOR EACH ROW EXECUTE FUNCTION infra.set_iteration_before_insert();

