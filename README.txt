Project - Cloud Side Setup Project Structure:

1. anpr_reciever7.py - the python script that implements the functionality of the ANPR app 

2. best.pt - the YOLOv8 vehicle number plate detection model trained on a custom vehicle number plate image dataset

3. Dockerfile - the file used to configure and build the docker image of the ANPR app

4. requirements.txt - the file containing the names of the python packages to be installed while building the docker image of the ANPR app, needed for its functionality

5. init.sql - the sql file containing SQL commands that need to be run on creation of the PostgreSQL deployment, inside it, to setup and initialize the database

6. kafka-service.yaml : the file needed to create and setup the kafka-service in the kubernetes cluster

7. kafka-deployment.yaml - the file needed to deploy kafka as a kubernetes deployment in the kubernetes cluster

8. postgres-service.yaml - the file needed to create and setup the psotgres-service in the kubernetes cluster

9. postgres-deployment.yaml - the file needed to deploy PostgreSQL as a kubernetes deployment in the kubernetes cluster

10. app-deployment.yaml - the file needed to deploy the ANPR app as a kubernetes deployment in the kubernetes cluster



Steps to setup the cloud side setup of the project:

1. Build the docker image of the ANPR app, locally:

    docker build -t <IMAGE_NAME> .

2. Create a Google Cloud account

3. Download the Google Cloud Shell SDK

4. Setup the Google Cloud Shell:

    a) Login into your Google Cloud Account using the Google Cloud Shell:

        gcloud auth login

    b) Set parameters like Project ID, Region, Zone:

        gcloud config set project <PROJECT_ID>

        gcloud config set compute/region <REGION>

        gcloud config set compute/zone <ZONE>

    c) Enable the required Google Cloud APIs (Compute Engine API & Kubernetes Engine API ):

        gcloud services enable compute.googleapis.com container.googleapis.com

    d) Enable the required Google Cloud services:

        i) Compute service:

            gcloud services enable compute

        ii) Container service:

            gcloud services enable container
    
    e) Install the Google Kubernetes Engine (GKE) authentication plugin for the kubectl command:

        gcloud components install gke-gcloud-auth-plugin

5. Setup the kubernetes cluster on GKE:

    a) Create the kubernetes cluster:

        gcloud container clusters create <CLUSTER_NAME> --num-nodes=1 --zone=<ZONE> --enable-ip-alias --disk-type=pd-standard --disk-size=50GB --machine-type=custom-8-16384

    b) Create an artifact registry for stroring the ANPR app docker image that is accessible from GKE

        gcloud artifacts repositories create <REGISTRY_NAME> --repository-format=docker --location=<REGION> --description=<DESCRIPTION>

    c) Authenticate to the artifact registry:

        gcloud auth configure-docker <REGION>-docker.pkg.dev

    d) Tag the local ANPR app docker image:

        docker tag <IMAGE_NAME> <REGION>-docker.pkg.dev/<PROJECT_ID>/<REGISTRY_NAME>/<IMAGE_NAME>
    
    e) Push the tagged local ANPR app docker image into the artifact registry in cloud:

        docker push <REGION>-docker.pkg.dev/<PROJECT_ID>/<REGISTRY_NAME>/<IMAGE_NAME>

    f) Fetch credentials of the cluster to authenticate to it:

        gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE>

6. Create necessary deployments,services and configmaps in the kubernetes cluster:

    a) Create a LoadBalancer type kuberenetes service for the Raspberry Pi (external device) and the anpr-app deployment to interact with kafka:

        kubectl apply -f kafka-service.yaml
    
    b) Obtain the external IP address (KAFKA_IP_ADDRESS) exposed by kafka-service and replace the value of KAFKA_CFG_ADVERTISED_LISTENERS in the kafka-deployment.yaml file with "PLAINTEXT://<KAFKA_IP_ADDRESS>:9092"

        kubectl get svc kafka-service

    c) Deploy kafka (deployment name : kafka) as a kuberenetes deployment in the cluster:

        kubectl apply -f kafka-deployment.yaml

    d) Create a LoadBalancer type kubernetes service to expose a connection for external devices to the PostgreSQL database and for the anpr-app to interact with the PostgreSQL database:

        kubectl apply -f postgres-service.yaml

    e) Create a kubernetes configmap for setting up and initializing the PostgreSQL database upon deployment:

        kubectl create configmap postgres-initdb-config --from-file=init.sql
    
    f) Deploy PostgreSQL (deployment name : postgres) as a kuberenetes deployment in the cluster:

        kubectl apply -f postgres-deployment.yaml

    g) Deploy the ANPR app (deployment name : anpr-app) as a kubernetes deployment in the cluster:

        kubectl apply -f postgres-deployment.yaml

    h) Obtain the external IP address (POSTGRES_IP_ADDRESS) exposed by postgres-service:

        kubectl get svc postgres-service

    i) Connect to the PostgreSQL database in the cluster from an external device through psql (PostgreSQL shell) to view it and interact with it:

        psql -h <POSTGRES_IP_ADDRESS> -d anpr -U root

    j) View logs of any pod of any deployment:

        kubectl logs <POD_NAME>

7. The Cloud side setup is now setup as a kubernetes cluster and is ready. Initiate data streaming from the Raspberry Pi to the cloud side setup and view the results


Algorithm:

1. The edge side script hits an API and retrieves the coordinates of the starting points and ending points of various no-parking zones and stores them in a python list

2.The main thread continuously checks if the coordinates measured by the GPS module matches the coordinates of any of the starting points of the no-parking zones

3. When a match of coordinates is found, a new camera thread is created that continuously streams the footage of vehicles parked at the no-parking zones as base64 encoded JPEG images through the camera module along with the coordinates of the starting point of the no-parking zone,using a kafka producer to a kafka message queue in the cloud. 

4. The data streamed to the kafka message queue is in json format (encoded before streaming) which contains the following fields:


    a) stream id : unique identifier for the stream of data
    b) frame id : unique identifier for each frame in a stream
    c) chunk id : unique identifier for each chunk of a frame (frames are divided into chunks before streaming so as to decrease the payload size of data being streamed into the kafka message queue which ensures smooth data streaming)
    d) total chunks : number of chunks that a frame has been split into
    e) data : a chunk of a frame
    f) latitude : latitude of the starting point of the no-parking zone
    g) longitude : longitude of the starting point of the no-parking zone

5. The streaming stops when the coordinates of the ending point of the corresponding no-parking zone is matched with the coordinates measured by the GPS module

6. The script continues to check if the coordinates measured by the GPS module matches the coordinates of any of the starting points of any other no-parking zones

7. On the cloud side, the json data streamed to the kafka message queue is stored inside the message queue, waiting to be consumed by a kafka consumer

8. The cloud side script uses multithreading where the main thread uses a kafka consumer that continuously checks the kafka message queue for any data streamed from the edge side

9.  If the kafka message queue has any data, the kafka consumer consumes it

10. The main thread uses a python dictionary to keep a record of stream ids, their corresponding frame ids and the chunk ids of the corresponding frame ids and the data of the corresponding chunk ids

11. Every time it reads a data message from the kafka message queue, it updates the data record python dictionary accordingly

12. Every time it reads a data message from the kafka message queue, it checks if all the chunks of the frame corresponding to the frame id of the message have been read. 

13. If yes, it combines all the chunks of that frame to build a frame which along with the stream id, frame id, latitude and longitude are packaged as a data element in the form of a python dictionary. Else, it continues reading data messages from the kafka message queue

14. The script also maintains a mapping between active stream ids and queues assigned to them using a python dictionary. This python dictionary is shared among the main thread and worker threads handling different data streams.

15. If the frame built is the first frame of a stream id, then it allocates a queue to the stream id to which the data element is added. 

16. The stream id and its queue are added to the queues python dictionary

17. A worker thread is created to process the data of the stream id that accesses data from the queue allocated to it

18. Else, the main thread adds the data element to the queue allocated to the stream 

19. Each worker thread handles the processing of data corresponding to a stream id

20. Each data element in the queue of a stream id is read by its worker thread, which parses the frame from it and reads it using OpenCV

21. A YOLO object detection model is run on the frame to detect a vehicle number plate in it with a bounding box

22. If a vehicle number plate is detected, the number plate is cropped out from the frame along the bounding box and PaddleOCR is run on the cropped number plate to read the text from the number plate

23. The text read from the number plate is formatted accordingly, to form a string of characters that is matched with a regular expression to verify that a valid registration number has been read

24. A PostgreSQL database is connected to the script which maintains 3 tables:

    a) contacts : stores vehicle registration numbers and the corresponding registered email ids
    b) violations: stores no-parking violation details of vehicles (registration number, date of violation, coordinates of no-parking zone where vehicle was parked)
    c) fines : stores fine amounts fro respective violation categories

25. If a valid registration number has been read, a function call is made that checks whether the violating vehicle has already been fined on the same day at the same no-parking zone by verifying with records in the violations table of the database

26. If yes, the vehicle is not fined again

27. Else, the vehicle is fined for no-parking violation and the violation details are inserted into the violations table of the database. Another function call is made that emails the violation details to the violator using the registered email id from the contacts table of the database.


anpr_reciever7.py:

variables:

1. Global Variables:

a) DB_CONFIG: Dictionary containing PostgreSQL database credentials sourced from environment variables. Used to establish database connections securely.

b) EMAIL_CONFIG: Dictionary containing email configuration parameters sourced from environment variables, such as SMTP server, port, and sender credentials.

c) model: YOLOv8 model loaded from a pre-trained weights file named best.pt, used for object detection in video frames.

d) ocr: Instance of PaddleOCR configured for English language and angle classification, used to read and extract text (such as number plates) from images.

e) VALID_STATE_CODES: A set of valid state codes in India used to validate if a detected vehicle registration number is legitimate and conforms to the Indian format.

f) INDIAN_NUMBER_PLATE_REGEX: A regular expression pattern used to match and validate standard Indian vehicle number plates.

g) KAFKA_BROKER: Kafka broker address retrieved from environment variables, used to configure Kafka producer/consumer connections.

h) TOPIC: Name of the Kafka topic being consumed or produced, retrieved from environment variables.

i) GROUP_ID: Consumer group ID used for Kafka consumer configuration to manage offsets and consumer load balancing.

j) active_streams: A dictionary used to track currently running video streams, where keys are stream IDs and values are likely thread references or stream handlers.

k) active_streams_lock: Threading lock used to prevent race conditions when modifying the active_streams dictionary across multiple threads.

l) frame_buffers: Dictionary that stores buffered video frames per stream, used for temporarily holding video data for processing or storage.


2. Function Name: video_worker_thread(stream_id, frame_queue, output_filename)

a) stream_id: Identifier for the video stream currently being processed. Used to distinguish between different streams handled concurrently.

b) frame_queue: A Queue object used for receiving frame messages belonging to the current stream. Acts as an input buffer to the thread.

c) output_filename: Name of the video file to be saved after processing all frames from the stream.

d) first_frame: Stores the first successfully decoded frame to infer video resolution for initializing a video writer. Used to ensure that at least one valid frame exists before saving the video.

e) valid_number_plates: A set that stores all uniquely detected valid Indian number plates throughout the video stream.

f) fresh_number_plates: A set that stores number plates identified as "fresh violations" based on logic in verify_violations() (e.g., not previously recorded).

g) lat_set: A set that collects all unique latitude values associated with the frames for this stream.

h) long_set: A set that collects all unique longitude values associated with the frames for this stream.

i) message: A dictionary representing a single frame’s metadata and image data received from the queue.

j) frame_data: A bytes object decoded from the base64-encoded string of the image frame.

k) np_frame: A NumPy array converted from frame_data, representing raw image bytes.

l) frame: Decoded image using OpenCV, in BGR color format.

m) frame_rgb: RGB color version of the frame, used as input to the object detection model and for displaying text/bounding boxes.

n) results: Output from the object detection model applied on frame_rgb. Contains bounding box and object info.

o) result.boxes: List of detected bounding boxes returned by the model for one frame.

p) x1, y1, x2, y2: Coordinates of the bounding box used to crop out the number plate from the frame.

q) cropped_plate: Region of the image corresponding to the detected number plate, cropped using bounding box coordinates.

r) gray_plate: Grayscale version of cropped_plate, used for Optical Character Recognition (OCR) to improve accuracy.

s) ocr_result: Output from the OCR engine, containing text extracted from the number plate.

t) detected_text: Raw string representation of the text detected by OCR, cleaned and formatted before validation.

u) matches: List of regex matches found in the cleaned detected_text that correspond to valid Indian number plate formats.

v) state_code: The regional identifier extracted from the number plate, verified against a predefined list of valid Indian state codes.

w) number_plate: Concatenated and formatted representation of the complete license plate extracted from the OCR results.

x) violation_frame: The RGB frame containing a fresh violation, later used in email alerts.


3. Function Name: main()

a) consumer: Kafka Consumer object used to subscribe and poll messages from a Kafka topic containing video frame data.

b) msg: A message object received from Kafka containing serialized video frame and metadata.

c) message: A Python dictionary decoded from msg. Contains keys like frame_id, stream_id, lat, long, data, chunk_id, and total_chunks.

d) stream_id: Used to uniquely identify the source stream of the current message, used for grouping frames.

e) frame_id: Numeric identifier of the frame within a stream. Used to track and reconstruct chunked frames.

f) lat: Latitude metadata associated with the location from which the video frame was captured.

g) long: Longitude metadata associated with the location from which the video frame was captured.

h) chunk_id: Identifier of the current chunk (if the frame is split into multiple parts).

i) total_chunks: Total number of chunks the full frame is divided into.

j) data: The actual base64-encoded string representing the frame (or part of it).

k) frame_buffers: A nested dictionary used to temporarily store incomplete (chunked) frame data until all chunks for a given frame are received. Structure: frame_buffers[stream_id][frame_id][chunk_id] = data.

l) complete_message: A fully reassembled frame message ready to be sent to the worker thread for processing. Created when all chunks of a frame are available.

m) output_filename: A string representing the name of the output video file for a given stream.

n) frame_queue: A Queue created for passing decoded messages to the corresponding worker thread.

o) worker: A thread object responsible for running the video_worker_thread() function in the background for a specific stream.

p) active_streams: A shared global dictionary that maps stream_id to the associated active frame queue. Used to keep track of live worker threads and their queues.

q) active_streams_lock: A threading lock used to synchronize access to the active_streams dictionary across multiple threads.



4. Function Name: verify_violations

a) reg_no: Vehicle registration number to be verified for a violation entry in the database.

b) lat: Latitude coordinate of the location where the vehicle was identified; used to determine if the violation occurred at a specific point.

c) long: Longitude coordinate of the location where the vehicle was identified; used in conjunction with latitude to pinpoint the violation.

d) frame_rgb: The image frame in RGB format where the vehicle was captured violating the no-parking rule. This frame is later converted and stored in the database.

e) today: Stores the current date (without time), used to verify whether a violation already exists for the same vehicle at the same location on the same day.

f) fresh: A boolean flag used to indicate whether the current violation is new and has been recorded successfully (True) or already exists in the database (False).

g) image_bytes: Byte-encoded form of the violation image, generated from the input frame, used for storing the image in binary format in the PostgreSQL database.

h) conn: Connection object to the PostgreSQL database using credentials provided in DB_CONFIG.

i) cursor: Cursor object used to execute SQL commands on the connected database.

j) result: Holds the result of the SQL query used to check for existing violations or retrieve information.


5. Function Name: send_email_to_violator

a) reg_num: The registration number of the vehicle for which the violation email is to be sent.

b) frame: Image frame (in BGR or RGB format) showing the no-parking violation, which will be attached to the email.

c) lat: Latitude coordinate of the violation location, used for describing the violation in the email body.

d) long: Longitude coordinate of the violation location, paired with lat to show exact location in the email body.

e) today: Current date (without time), used to provide the date of the violation in the email.

f) formatted_date: Human-readable formatted version of today’s date (e.g., “May 14, 2025”), used in the email body.

g) conn: Database connection object to access the contact and fine details.

h) cursor: Cursor object used to execute SQL queries within the email function.

i) result: Holds data retrieved from SQL queries, such as email address and fine amount.

j) recipient_email: Email address fetched from the database associated with the provided vehicle registration number.

k) fine_amount: Fine value fetched from the database corresponding to the “no-parking” violation category.

l) image_filename: Filename assigned to the image when attached to the email. It is a static name “violation.png”.

m) img_encoded: Encoded image object in PNG format created from the input frame using OpenCV.

n) img_bytes: Byte stream of the encoded image, attached to the email as an attachment.

o) msg: MIMEMultipart email object representing the full email including body and attachment.

p) body: Plain-text string describing the violation details, including vehicle number, fine amount, coordinates, and date.

q) part: MIMEBase object used to store the image attachment in a format compatible with the email.

r) server: SMTP server object used to send the constructed email via the configured SMTP credentials.


6. Function Name: create_topic_if_missing

a) admin_client: An instance of Kafka’s AdminClient that interacts with the Kafka cluster for administrative operations.

b) topic_metadata: Metadata object that stores information about available Kafka topics, used to check if the required topic already exists.

c) new_topic: Instance of NewTopic from Kafka, used to define a new topic configuration (e.g., number of partitions, replication factor).


Python Imports:

1. OpenCV : Used to read and process image data

2. Numpy : Used alongside OpenCV to read,process and run the number plate detection model on image data

3. Json : Used for the interconversion between json data format and python dictionaries

4. Base64 : Used to encode and decode binary data to/from Base64 format while dealing with image data

5. Io.BytesIO : Used for handling in-memory binary streams, often for processing images without writing them to disk

6. Threading : Used to implement multithreading in cloud side script

7. Time : Used to introduce delays at certains checkpoints in the cloud side script to reduce processing overhead

8. queue.Queue : Used to implement thread safe queues that are allocated to streams for holding stream data on the cloud side

9. Date : Used to retrieve current date

10. Confluent_kafka : Used to implement kafka producer on the edge side and kafka consumer on the cloud side

11. Torch : A deep learning framework used for training and inference of the number plate detection model

12. Ultralytics.YOLO : Neural network and framework used to train the number plate detection model

13. PaddleOCR : An OCR framework that is used to read text from the vehicle number plates

14. Re : Used to implement regular expressions and pattern matching to identify valid registration numbers

15. Psycopg2 : A PostgreSQL database adapter used to connect and run queries with the PostgreSQL database

16.Smtplib : Used to send mails to violators using SMTP

17.Email : Used to create emails that are sent to violators


    






