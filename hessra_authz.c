/*-------------------------------------------------------------------------
 * postgres-plugin.c
 *
 * C source code for the Hessra Postgres authorization plugin.
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "miscadmin.h" // For GetConfigOptionByName, etc. (Needed for GUC later)
#include "utils/elog.h" // For ereport, ERROR, NOTICE, etc.
#include "utils/guc.h" // For GetConfigOptionByName

// Include the header generated by cbindgen from the Rust FFI crate
// The actual path might need adjustment in the Makefile depending on build steps
// hessra-ffi.h includes hessra_token_verify, hessra_public_key_from_file, HessraResult, etc.
#include "hessra_ffi.h"

PG_MODULE_MAGIC;

// --- Global Variables (Use with caution, consider GUCs or session state) ---
// Public key path - expected to be mounted or copied into the container
#define HESSRA_PUBLIC_KEY_PATH "/etc/postgresql/hessra_key.pem"
#define HESSRA_CONFIG_KEY_PATH "hessra.public_key_path"

// Global variable to hold the configured path
char *hessra_public_key_path = NULL;

// --- Function Prototypes ---

PG_FUNCTION_INFO_V1(pg_verify_hessra_token);
PG_FUNCTION_INFO_V1(pg_verify_hessra_service_chain);
void _PG_init(void);

// --- Module Init Function ---

/*
 * _PG_init
 * 
 * This function is called when the module is loaded.
 * It registers custom GUC parameters.
 */
void
_PG_init(void)
{
    /* Define custom GUC variables */
    DefineCustomStringVariable(
        "hessra.public_key_path",                  /* name */
        "Path to the Hessra public key file",      /* short_desc */
        "Specifies the file system path to the PEM-encoded public key used for token verification", /* long_desc */
        &hessra_public_key_path,                   /* variable address */
        HESSRA_PUBLIC_KEY_PATH,                    /* boot_val */
        PGC_USERSET,                               /* context */
        0,                                         /* flags */
        NULL,                                      /* check_hook */
        NULL,                                      /* assign_hook */
        NULL                                       /* show_hook */
    );

    ereport(DEBUG1,
            (errmsg("Hessra PostgreSQL extension initialized. Default public key path: %s", 
                    HESSRA_PUBLIC_KEY_PATH)));
}

// --- Function Definitions ---

/**
 * SQL-callable function to verify a Hessra token.
 *
 * Args:
 *   PG_GETARG_TEXT_PP(0): The Hessra token string.
 *   PG_GETARG_TEXT_PP(1): The required subject string.
 *   PG_GETARG_TEXT_PP(2): The required resource string.
 *
 * Returns:
 *   Boolean indicating if the token is valid and grants the permission.
 */
Datum
pg_verify_hessra_token(PG_FUNCTION_ARGS)
{
    text *token_text = PG_GETARG_TEXT_PP(0);
    text *subject_text = PG_GETARG_TEXT_PP(1);
    text *resource_text = PG_GETARG_TEXT_PP(2);

    char *token_cstr = text_to_cstring(token_text);
    char *subject_cstr = text_to_cstring(subject_text);
    char *resource_cstr = text_to_cstring(resource_text);

    HessraPublicKey *public_key = NULL;
    HessraResult key_load_result;
    HessraResult verify_result;
    bool is_valid = false;
    char *key_path_cstr = NULL;

    // TODO: Implement proper initialization (e.g., via _PG_init)
    // hessra_init(); // Consider where/how often to call this

    // 1. First check if there's a custom path configured in PostgreSQL settings
    if (hessra_public_key_path != NULL && hessra_public_key_path[0] != '\0') {
        // Use the config-specified path
        key_path_cstr = hessra_public_key_path;
        ereport(DEBUG1,
                (errcode(ERRCODE_SUCCESSFUL_COMPLETION),
                 errmsg("Using configured key path: %s", key_path_cstr)));
    } else {
        // Fall back to the default path
        key_path_cstr = HESSRA_PUBLIC_KEY_PATH;
        ereport(DEBUG1,
                (errcode(ERRCODE_SUCCESSFUL_COMPLETION),
                 errmsg("Using default key path: %s", key_path_cstr)));
    }

    // 2. Load the public key from the determined path
    key_load_result = hessra_public_key_from_file(key_path_cstr, &public_key);

    if (key_load_result != SUCCESS || public_key == NULL) {
        char *err_msg = hessra_error_message(key_load_result);
        char *safe_err_msg = (err_msg != NULL) ? err_msg : "Unknown key loading error";
        ereport(ERROR,
                (errcode(ERRCODE_EXTERNAL_ROUTINE_INVOCATION_EXCEPTION),
                 errmsg("Failed to load Hessra public key from %s: %s", key_path_cstr, safe_err_msg)));
        if (err_msg != NULL) {
            hessra_string_free(err_msg);
        }
        // Cleanup arguments even on error before returning
        pfree(token_cstr);
        pfree(subject_cstr);
        pfree(resource_cstr);
        PG_RETURN_BOOL(false); // Or throw error
    }

    // 3. Call the Rust FFI verification function
    verify_result = hessra_token_verify(token_cstr, public_key, subject_cstr, resource_cstr);

    // 4. Process the result
    if (verify_result == SUCCESS) {
        is_valid = true;
    } else {
        is_valid = false;
        // Optional: Log specific verification failures as NOTICE or WARNING instead of ERROR?
        // char *err_msg = hessra_error_message(verify_result);
        // char *safe_err_msg = (err_msg != NULL) ? err_msg : "Unknown verification error";
        // ereport(NOTICE, (errmsg("Hessra token verification failed: %s", safe_err_msg)));
        // if (err_msg != NULL) {
        //     hessra_string_free(err_msg);
        // }
    }

    // 5. Clean up allocated resources
    if (public_key != NULL) {
        hessra_public_key_free(public_key);
    }
    pfree(token_cstr);
    pfree(subject_cstr);
    pfree(resource_cstr);

    // 6. Return the boolean result
    PG_RETURN_BOOL(is_valid);
}

/**
 * SQL-callable function to verify a Hessra service chain token.
 *
 * Args:
 *   PG_GETARG_TEXT_PP(0): The Hessra token string.
 *   PG_GETARG_TEXT_PP(1): The required subject string.
 *   PG_GETARG_TEXT_PP(2): The required resource string.
 *   PG_GETARG_TEXT_PP(3): JSON array of service node objects with component and public_key fields.
 *   PG_GETARG_TEXT_PP(4): The component name to check in the service chain.
 *
 * Returns:
 *   Boolean indicating if the token is valid and grants the permission for the service chain.
 */
Datum
pg_verify_hessra_service_chain(PG_FUNCTION_ARGS)
{
    text *token_text = PG_GETARG_TEXT_PP(0);
    text *subject_text = PG_GETARG_TEXT_PP(1);
    text *resource_text = PG_GETARG_TEXT_PP(2);
    text *service_nodes_json_text = PG_GETARG_TEXT_PP(3);
    text *component_text = PG_GETARG_TEXT_PP(4);

    char *token_cstr = text_to_cstring(token_text);
    char *subject_cstr = text_to_cstring(subject_text);
    char *resource_cstr = text_to_cstring(resource_text);
    char *service_nodes_json_cstr = text_to_cstring(service_nodes_json_text);
    char *component_cstr = text_to_cstring(component_text);

    HessraPublicKey *public_key = NULL;
    HessraResult key_load_result;
    HessraResult verify_result;
    bool is_valid = false;
    char *key_path_cstr = NULL;
    char *err_msg = NULL;
    char *safe_err_msg = NULL;

    // 1. First check if there's a custom path configured in PostgreSQL settings
    if (hessra_public_key_path != NULL && hessra_public_key_path[0] != '\0') {
        // Use the config-specified path
        key_path_cstr = hessra_public_key_path;
        ereport(DEBUG1,
                (errcode(ERRCODE_SUCCESSFUL_COMPLETION),
                 errmsg("Using configured key path: %s", key_path_cstr)));
    } else {
        // Fall back to the default path
        key_path_cstr = HESSRA_PUBLIC_KEY_PATH;
        ereport(DEBUG1,
                (errcode(ERRCODE_SUCCESSFUL_COMPLETION),
                 errmsg("Using default key path: %s", key_path_cstr)));
    }

    // 2. Load the public key from the determined path
    key_load_result = hessra_public_key_from_file(key_path_cstr, &public_key);

    if (key_load_result != SUCCESS || public_key == NULL) {
        char *err_msg = hessra_error_message(key_load_result);
        char *safe_err_msg = (err_msg != NULL) ? err_msg : "Unknown key loading error";
        ereport(ERROR,
                (errcode(ERRCODE_EXTERNAL_ROUTINE_INVOCATION_EXCEPTION),
                 errmsg("Failed to load Hessra public key from %s: %s", key_path_cstr, safe_err_msg)));
        if (err_msg != NULL) {
            hessra_string_free(err_msg);
        }
        // Cleanup arguments even on error before returning
        pfree(token_cstr);
        pfree(subject_cstr);
        pfree(resource_cstr);
        pfree(service_nodes_json_cstr);
        pfree(component_cstr);
        PG_RETURN_BOOL(false);
    }

    // 3. Call the Rust FFI service chain verification function
    verify_result = hessra_token_verify_service_chain(
        token_cstr,
        public_key,
        subject_cstr,
        resource_cstr,
        service_nodes_json_cstr,
        component_cstr
    );

    // 4. Process the result
    if (verify_result == SUCCESS) {
        is_valid = true;
    } else {
        is_valid = false;
        // Log specific verification failures for debugging
        err_msg = hessra_error_message(verify_result);
        safe_err_msg = (err_msg != NULL) ? err_msg : "Unknown verification error";

        // Only log at DEBUG level in production; can use NOTICE during development
        ereport(DEBUG1,
                (errmsg("Hessra service chain verification failed: %s", safe_err_msg)));

        if (err_msg != NULL) {
            hessra_string_free(err_msg);
        }
    }

    // 5. Clean up allocated resources
    if (public_key != NULL) {
        hessra_public_key_free(public_key);
    }
    pfree(token_cstr);
    pfree(subject_cstr);
    pfree(resource_cstr);
    pfree(service_nodes_json_cstr);
    pfree(component_cstr);

    // 6. Return the boolean result
    PG_RETURN_BOOL(is_valid);
}

// TODO: Add _PG_init and _PG_fini functions if needed for global setup/teardown
// (e.g., calling hessra_init, managing GUCs) 