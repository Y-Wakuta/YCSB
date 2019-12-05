/*
 * Copyright 2015 YCSB contributors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License. You
 * may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License. See accompanying
 * LICENSE file.
 */

package site.ycsb.db;

import com.google.api.client.auth.oauth2.Credential;
import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
import com.google.datastore.v1.*;
import com.google.datastore.v1.CommitRequest.Mode;
import com.google.datastore.v1.ReadOptions.ReadConsistency;
import com.google.datastore.v1.client.Datastore;
import com.google.datastore.v1.client.DatastoreException;
import com.google.datastore.v1.client.DatastoreFactory;
import com.google.datastore.v1.client.DatastoreHelper;
import com.google.datastore.v1.client.DatastoreOptions;

import site.ycsb.ByteIterator;
import site.ycsb.DB;
import site.ycsb.DBException;
import site.ycsb.Status;
import site.ycsb.StringByteIterator;

import org.apache.log4j.Level;
import org.apache.log4j.Logger;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.Vector;

import javax.annotation.Nullable;

/**
 * Google Cloud Datastore Client for YCSB.
 */

public class GoogleDatastoreClient extends DB {
  /**
   * Defines a MutationType used in this class.
   */
  private enum MutationType {
    UPSERT,
    UPDATE,
    DELETE
  }

  /**
   * Defines a EntityGroupingMode enum used in this class.
   */
  private enum EntityGroupingMode {
    ONE_ENTITY_PER_GROUP,
    MULTI_ENTITY_PER_GROUP
  }

  private static Logger logger =
      Logger.getLogger(GoogleDatastoreClient.class);

  // Read consistency defaults to "STRONG" per YCSB guidance.
  // User can override this via configure.
  private enum ReadConsistency {
    STRONG,
    EVENTUAL
  }
  private ReadConsistency readConsistency = ReadConsistency.STRONG;

  private EntityGroupingMode entityGroupingMode =
      EntityGroupingMode.ONE_ENTITY_PER_GROUP;

  private String rootEntityName;

  private Datastore datastore = null;

  private static boolean skipIndex = true;

  /**
   * Initialize any state for this DB. Called once per DB instance; there is
   * one DB instance per client thread.
   */
  @Override
  public void init() throws DBException {
    String debug = getProperties().getProperty("googledatastore.debug", null);
    if (null != debug && "true".equalsIgnoreCase(debug)) {
      logger.setLevel(Level.DEBUG);
    }

    String skipIndexString = getProperties().getProperty(
        "googledatastore.skipIndex", null);
    if (null != skipIndexString && "false".equalsIgnoreCase(skipIndexString)) {
      skipIndex = false;
    }

    // We need the following 3 essential properties to initialize datastore:
    //
    // - DatasetId,
    // - Path to private key file,
    // - Service account email address.
    String datasetId = getProperties().getProperty(
        "googledatastore.datasetId", null);
    if (datasetId == null) {
      throw new DBException(
          "Required property \"datasetId\" missing.");
    }

    String privateKeyFile = getProperties().getProperty(
        "googledatastore.privateKeyFile", null);
    String serviceAccountEmail = getProperties().getProperty(
        "googledatastore.serviceAccountEmail", null);

    // Below are properties related to benchmarking.

    String readConsistencyConfig = getProperties().getProperty(
        "googledatastore.readConsistency", null);
    if (readConsistencyConfig != null) {
      try {
        this.readConsistency = ReadConsistency.valueOf(
            readConsistencyConfig.trim().toUpperCase());
      } catch (IllegalArgumentException e) {
        throw new DBException("Invalid read consistency specified: " +
            readConsistencyConfig + ". Expecting STRONG or EVENTUAL.");
      }
    }

    //
    // Entity Grouping Mode (googledatastore.entitygroupingmode), see
    // documentation in conf/googledatastore.properties.
    //
    String entityGroupingConfig = getProperties().getProperty(
        "googledatastore.entityGroupingMode", null);
    if (entityGroupingConfig != null) {
      try {
        this.entityGroupingMode = EntityGroupingMode.valueOf(
            entityGroupingConfig.trim().toUpperCase());
      } catch (IllegalArgumentException e) {
        throw new DBException("Invalid entity grouping mode specified: " +
            entityGroupingConfig + ". Expecting ONE_ENTITY_PER_GROUP or " +
            "MULTI_ENTITY_PER_GROUP.");
      }
    }

    this.rootEntityName = getProperties().getProperty(
        "googledatastore.rootEntityName", "YCSB_ROOT_ENTITY");

    // Setup the connection to Google Cloud Datastore with the credentials
    // obtained from the configure.
    //if (serviceAccountEmail != null && privateKeyFile != null) {
    //  credential = GoogleCredentials..getServiceAccountCredential(
    //      serviceAccountEmail, privateKeyFile);
    //  logger.info("Using JWT Service Account credential.");
    //  logger.info("DatasetID: " + datasetId + ", Service Account Email: " +
    //      serviceAccountEmail + ", Private Key File Path: " + privateKeyFile);
    //} else {
    //  logger.info("Using default gcloud credential.");
    //  logger.info("DatasetID: " + datasetId
    //      + ", Service Account Email: " + ((GoogleCredential) credential).getServiceAccountId());
    //}

    datastore = DatastoreOptions.getDefaultInstance().getService();

    logger.info("Datastore client instance created: " +
        datastore.toString());
  }

  @Override
  public Status read(String table, String key, Set<String> fields,
                     Map<String, ByteIterator> result) {
    Key datastoreKey = buildPrimaryKey(table, key);
    Entity response;
    try {
      response = readConsistency == ReadConsistency.STRONG
          ? datastore.get(datastoreKey)
          : datastore.get(datastoreKey, ReadOption.eventualConsistency());
    } catch (DatastoreException exception) {
      logger.error(
          String.format("Datastore Exception when reading (%s): %s %s",
              exception.getMessage(),
              exception.getCode()));

      // DatastoreException.getCode() returns an HTTP response code which we
      // will bubble up to the user as part of the YCSB Status "name".
      return new Status("ERROR-" + exception.getCode(), exception.getMessage());
    }

    if (response == null) {
      return new Status("ERROR-404", "Not Found, key is: " + key);
    }

    logger.debug("Read entity: " + response.toString());

    Map<String, Value<?>> properties = response.getProperties();
    Set<String> propertiesToReturn =
        (fields == null ? properties.keySet() : fields);

    for (String name : propertiesToReturn) {
      if (properties.containsKey(name)) {
        result.put(name, new StringByteIterator(properties.get(name).toString()));
      }
    }

    return Status.OK;
  }

  @Override
  public Status scan(String table, String startkey, int recordcount,
                     Set<String> fields, Vector<HashMap<String, ByteIterator>> result) {
    // TODO: Implement Scan as query on primary key.
    return Status.NOT_IMPLEMENTED;
  }

  @Override
  public Status update(String table, String key,
                       Map<String, ByteIterator> values) {

    return doSingleItemMutation(table, key, values, MutationType.UPDATE);
  }

  @Override
  public Status insert(String table, String key,
                       Map<String, ByteIterator> values) {
    // Use Upsert to allow overwrite of existing key instead of failing the
    // load (or run) just because the DB already has the key.
    // This is the same behavior as what other DB does here (such as
    // the DynamoDB client).
    return doSingleItemMutation(table, key, values, MutationType.UPSERT);
  }

  @Override
  public Status delete(String table, String key) {
    return doSingleItemMutation(table, key, null, MutationType.DELETE);
  }

  private Key buildPrimaryKey(String table, String key) {
    KeyFactory keyFactory = datastore.newKeyFactory();
    if (this.entityGroupingMode == EntityGroupingMode.MULTI_ENTITY_PER_GROUP) {
      // All entities are in side the same group when we are in this mode.
      keyFactory.addAncestors(PathElement.of(rootEntityName, "default"));
    }

    return keyFactory.setKind(table).newKey(key);
  }

  private Status doSingleItemMutation(String table, String key,
                                      @Nullable Map<String, ByteIterator> values,
                                      MutationType mutationType) {
    Key datastoreKey = buildPrimaryKey(table, key);

    Entity.Builder entityBuilder = Entity.newBuilder(datastoreKey);
    for (Map.Entry<String, ByteIterator> val : values.entrySet()) {
      entityBuilder.set(val.getKey(), StringValue.newBuilder(val.getValue()
          .toString())
          .setExcludeFromIndexes(true).build());
    }
    Entity entity = entityBuilder.build();

    try {
      if (mutationType == MutationType.DELETE) {
        datastore.delete(datastoreKey);
      } else {
        datastore.put(entity);
      }
      logger.debug("successfully committed.");

    } catch (DatastoreException exception) {
      // Catch all Datastore rpc errors.
      // Log the exception, the name of the method called and the error code.
      logger.error(
          String.format("Datastore Exception when committing (%s): %s %s",
              exception.getMessage(),
              exception.getCode()));

      // DatastoreException.getCode() returns an HTTP response code which we
      // will bubble up to the user as part of the YCSB Status "name".
      return new Status("ERROR-" + exception.getCode(), exception.getMessage());
    }

    return Status.OK;
  }
}
