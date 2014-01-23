# Overall JSON schema

Most messsages in protocol are JSON objects or corresponding plain perl objects.
Thus, they can be defined as JSON schema.

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "description": "JSON schemata for CCF",
    "definitions": {
        "booleanString": {
            "description": "A boolean flag in string representation",
            "type": "string",
            "enum": ["true","false"]
        },
        "compilationIDs": {
            "description": "Compilation IDs",
            "type": "object",
            "patternProperties": {
                "": {
                    "description": "Compilation ID for key",
                    "type": "integer"
                }
            }
        },
        "compilerCharacteristics": {
            "description": "Compiler characteristics",
            "type": "object",
            "patternProperties": {
                "": {
                    "description": "Compiler characteristics for key",
                    "type": "array",
                    "items": [
                        {
                            "description": "Compiler description",
                            "type": "string"
                        },
                        {
                            "description": "C++11",
                            "type": "string",
                            "enum": ["true", "false"]
                        },
                        {
                            "description": "C++1y",
                            "type": "string",
                            "enum": ["true", "false"]
                        }
                    ],
                    "additionalItems": false,
                    "minItems": 3
                }
            }
        },
        "statusEnum": {
            "description": "Status 1:INVOKED/2:COMPILING/3:COMPILED/4:EXECUTED",
            "type": "integer",
            "enum": [1,2,3,4]
        },
        "result": {
            "descrpition": "Results of compilation/execution",
            "type": "object",
            "properties": {
                "output": {
                    "description": "Output string",
                    "type": "string"
                },
                "error": {
                    "description": "Error message",
                    "type": "string"
                }
            },
            "required": ["output"]
        }
    },
    "s3": {
        "description": "Schemata for S3",
        "request": {
            "description": "A request in S3",
            "type": "object",
            "properties": {
                "source": {
                    "description": "C++ source",
                    "type": "string"
                },
                "title": { "type": "string" },
                "keys": {
                    "description": "Compilation IDs",
                    "$ref": "#/definitions/compilationIDs"
                },
                "execute": {
                    "description": "A flag of execution",
                    "$ref": "#/definitions/booleanString"
                }
            },
            "required": ["source","keys","execute"]
        },
        "compile": {
            "description": "A compilation in S3",
            "type": "object",
            "properties": {
                "id": { "type": "integer" },
                "compile": {
                    "descrpition": "Compilation result",
                    "$ref": "#/definitions/result"
                },
                "execute": {
                    "descrpition": "Execution result",
                    "$ref": "#/definitions/result"
                },
                "status": { "$ref": "#/definitions/statusEnum" }
            },
            "required": ["id", "status"]
        }
    },
    "internal": {
        "description": "Schemata for internal protocol between servers",
        "list_request": {
            "description": "Request for list command",
            "type": "object",
            "properties": {
                "command": { "enum": ["list"] }
            },
            "required": ["command"]
        },
        "list_response": {
            "description": "Response for list command",
            "$ref": "#/definitions/compilerCharacteristics"
        },
        "invoke_request": {
            "description": "Request for invoke command",
            "type": "object",
            "properties": {
                "command": { "enum": ["invoke"] },
                "id": { "type": "integer" },
                "source": {
                    "description": "C++ source",
                    "type": "string"
                },
                "type": {
                    "description": "Compiler key",
                    "type": "string"
                },
                "execute": {
                    "description": "A flag of execution",
                    "$ref": "#/definitions/booleanString"
                }
            },
            "required": ["command", "id", "source", "type", "execute"]
        },
        "invoke_response": {
            "description": "Response for invoke command",
            "type": "object",
            "properties": {
                "id": {
                    "description": "Request ID",
                    "type": "integer"
                }
            },
            "required": ["id"]
        },
        "status_request": {
            "description": "Request for status command",
            "type": "object",
            "properties": {
                "command": { "enum": ["status"] },
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                }
            },
            "required": ["command","id"]
        },
        "status_response": {
            "description": "Response for status command",
            "type": "object",
            "properties": {
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                },
                "status": { "$ref": "#/definitions/statusEnum" }
            },
            "required": ["id","status"]
        },
        "result_request": {
            "description": "Request for result command",
            "type": "object",
            "properties": {
                "command": { "enum": ["result"] },
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                }
            },
            "required": ["command","id"]
        },
        "result_response": {
            "description": "Response for result command",
            "type": "object",
            "properties": {
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                },
                "compile": {
                    "descrpition": "Compilation result",
                    "$ref": "#/definitions/result"
                },
                "execute": {
                    "descrpition": "Execution result",
                    "$ref": "#/definitions/result"
                }
            },
            "required": ["id","compile"]
        }
    },
    "external": {
        "description": "Schemata for external protocol between server and client",
        "list_request": {
            "description": "Request for list command",
            "type": "object",
            "properties": {
                "command": { "enum": ["list"] }
            },
            "required": ["command"]
        },
        "list_response": {
            "description": "Response for list command",
            "$ref": "#/definitions/compilerCharacteristics"
        },
        "invoke_request": {
            "description": "Request for invoke command",
            "type": "object",
            "properties": {
                "command": { "enum": ["invoke"] },
                "source": {
                    "description": "C++ source",
                    "type": "string"
                },
                "title": { "type": "string" },
                "types": {
                    "description": "Compiler keys",
                    "type": "array",
                    "items": {
                        "description": "Compiler key",
                        "type": "string"
                    }
                },
                "execute": {
                    "description": "A flag of execution",
                    "$ref": "#/definitions/booleanString"
                }
            },
            "required": ["command"]
        },
        "invoke_response": {
            "description": "Response for invoke command",
            "type": "object",
            "properties": {
                "id": {
                    "description": "Request ID",
                    "type": "integer"
                },
                "keys": {
                    "description": "Compilation IDs",
                    "$ref": "#/definitions/compilationIDs"
                }
            },
            "required": ["id", "keys"]
        },
        "show_request": {
            "description": "Request for show command",
            "type": "object",
            "properties": {
                "command": { "enum": ["show"] },
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                }
            },
            "required": ["command"]
        },
        "status_request": {
            "description": "Request for status command",
            "type": "object",
            "properties": {
                "command": { "enum": ["status"] },
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                }
            },
            "required": ["command"]
        },
        "status_response": {
            "description": "Response for status command",
            "type": "object",
            "properties": {
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                },
                "status": { "$ref": "#/definitions/statusEnum" }
            },
            "required": ["id","status"]
        },
        "result_request": {
            "description": "Request for result command",
            "type": "object",
            "properties": {
                "command": { "enum": ["result"] },
                "id": {
                    "description": "Compilation ID",
                    "type": "integer"
                }
            },
            "required": ["command"]
        },
        "rlist_request": {
            "description": "Request for rlist command",
            "type": "object",
            "properties": {
                "command": { "enum": ["rlist"] },
                "from": {
                    "description": "The number of the start item in the resultant list. Defaults to the last ID",
                    "type": "integer"
                },
                "number": {
                    "description": "The number of items in the resultant list",
                    "type": "integer",
                    "default": 20
                }
            },
            "required": ["command"]
        },
        "cstats_request": {
            "description": "Request for cstats command",
            "type": "object",
            "properties": {
                "command": { "enum": ["cstats"] }
            },
            "required": ["command"]
        }
    }
}
```

# Storage in S3

## Request in S3

```json
{ "$ref": "#/s3/request" }
```

## Compilation in S3

```json
{ "$ref": "#/s3/compile" }
```

# Commands between servers

## Command: 'list' between servers

### Request

```json
{ "$ref": "#/internal/list_request" }
```

### Response

```json
{ "$ref": "#/internal/list_response" }
```

## Command: 'invoke' between servers

### Request

```json
{ "$ref": "#/internal/invoke_request" }
```

### Response

```json
{ "$ref": "#/internal/invoke_response" }
```

## Command: 'status' between servers

### Request

```json
{ "$ref": "#/internal/status_request" }
```

### Response

```json
{ "$ref": "#/internal/status_response" }
```

## Command: 'result' between servers

This is NO LONGER used.

### Request

```json
{ "$ref": "#/internal/result_request" }
```

### Response

```json
{ "$ref": "#/internal/result_response" }
```

# Commands between server and client

## Command: 'list' between server and client

### Request

```json
{ "$ref": "#/external/list_request" }
```

### Response

```json
{ "$ref": "#/external/list_response" }
```

## Command: 'invoke' between server and client

### Request

```json
{ "$ref": "#/external/invoke_request" }
```

### Response

```json
{ "$ref": "#/external/invoke_response" }
```

## Command: 'show' between server and client

### Request

```json
{ "$ref": "#/external/show_request" }
```

### Response

HTML

## Command: 'status' between server and client

### Request

```json
{ "$ref": "#/external/status_request" }
```

### Response

```json
{ "$ref": "#/external/status_response" }
```

## Command: 'result' between server and client

### Request

```json
{ "$ref": "#/external/result_request" }
```

### Response

HTML

## Command: 'rlist' between server and client

### Request

```json
{ "$ref": "#/external/cstats_request" }
```

### Response

HTML

## Command: 'cstats' between server and client

### Request

```json
{ "$ref": "#/external/cstats_request" }
```

### Response

HTML
