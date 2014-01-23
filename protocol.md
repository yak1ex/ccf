# Overview

One schema definition might be effective because types can be defined at one place.

# Storage in S3

## Request in S3

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "request",
    "description": "request in S3",
    "type": "object",
    "properties": {
        "source": {
            "description": "C++ source",
            "type": "string"
        },
        "title": {
            "description": "Title",
            "type": "string"
        },
        "keys": {
            "description": "Compilation IDs",
            "type": "object",
            "patternProperties": {
                "": {
                    "description": "Compilation ID for key",
                    "type": "integer"
                }
            }
        },
        "execute": {
            "description": "A flag of execution",
            "type": "string",
            "enum": ["true","false"]
        }
    },
    "required": ["source","keys","execute"]
}
```

## Compilation in S3

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "compilation",
    "description": "compilation in S3",
    "type": "object",
    "properties": {
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        },
        "compile": {
            "descrpition": "Compilation result",
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
        },
        "execute": {
            "descrpition": "Execution result",
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
        },
        "status": {
            "description": "Status 1:INVOKED/2:COMPILING/3:COMPILED/4:EXECUTED",
            "type": "integer",
            "enum": [1,2,3,4]
        }
    },
    "required": ["id", "status"]
}
```

# Commands between servers

## Command: 'list' between servers

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "list_request",
    "description": "command: list between servers",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["list"]
        }
    },
    "required": ["command"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "list_response",
    "description": "response for command: list between servers",
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
}
```

## Command: 'invoke' between servers

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "invoke_request",
    "description": "command: invoke from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["invoke"]
        },
        "id": {
            "description": "Request ID",
            "type": "integer"
        },
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
            "type": "string",
            "enum": ["true","false"]
        }
    },
    "required": ["command", "id", "source", "type", "execute"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "invoke_response",
    "description": "response for command: invoke between servers",
    "type": "object",
    "properties": {
        "id": {
            "description": "Request ID",
            "type": "integer"
        }
    },
    "required": ["id"]
}
```

## Command: 'status' between servers

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "status_request",
    "description": "command: status between servers",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["status"]
        },
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        }
    },
    "required": ["command","id"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "status_response",
    "description": "response for command: status between servers",
    "type": "object",
    "properties": {
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        },
        "status": {
            "description": "Status 1:INVOKED/2:COMPILING/3:COMPILED/4:EXECUTED",
            "type": "integer",
            "enum": [1,2,3,4]
        }
    },
    "required": ["id","status"]
}
```

## Command: 'result' between servers

This is NO LONGER used.

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "result_request",
    "description": "command: result between servers",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["result"]
        },
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        }
    },
    "required": ["command","id"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "result_response",
    "description": "response for command: result between servers",
    "type": "object",
    "properties": {
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        },
        "compile": {
            "descrpition": "Compilation result",
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
        },
        "execute": {
            "descrpition": "Execution result",
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
    "required": ["id","compile"]
}
```

# Commands between server and client

## Command: 'list' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "list_request",
    "description": "command: list from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["list"]
        }
    },
    "required": ["command"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "list_response",
    "description": "response for command: list to JS",
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
}
```

## Command: 'invoke' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "invoke_request",
    "description": "command: invoke from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["invoke"]
        },
        "source": {
            "description": "C++ source",
            "type": "string"
        },
        "title": {
            "description": "Title",
            "type": "string"
        },
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
            "type": "string",
            "enum": ["true","false"]
        }
    },
    "required": ["command"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "invoke_response",
    "description": "response for command: invoke to JS",
    "type": "object",
    "properties": {
        "id": {
            "description": "Request ID",
            "type": "integer"
        },
        "keys": {
            "description": "Compilation IDs",
            "type": "object",
            "patternProperties": {
                "": {
                    "description": "Compilation ID for key",
                    "type": "integer"
                }
            }
        }
    },
    "required": ["id", "keys"]
}
```

## Command: 'show' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "show_request",
    "description": "command: show from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["show"]
        },
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        }
    },
    "required": ["command"]
}
```

### Response

HTML

## Command: 'status' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "status_request",
    "description": "command: status from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["status"]
        },
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        }
    },
    "required": ["command"]
}
```

### Response

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "status_response",
    "description": "response for command: status to JS",
    "type": "object",
    "properties": {
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        },
        "status": {
            "description": "Status 1:INVOKED/2:COMPILING/3:COMPILED/4:EXECUTED",
            "type": "integer",
            "enum": [1,2,3,4]
        }
    },
    "required": ["id","status"]
}
```

## Command: 'result' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "result_request",
    "description": "command: result from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["result"]
        },
        "id": {
            "description": "Compilation ID",
            "type": "integer"
        }
    },
    "required": ["command"]
}
```

### Response

HTML

## Command: 'rlist' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "rlist",
    "description": "command: rlist from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["rlist"]
        },
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
}
```

### Response

HTML

## Command: 'cstats' between server and client

### Request

```json
{
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "cstats",
    "description": "command: cstats from JS",
    "type": "object",
    "properties": {
        "command": {
            "description": "Command type",
            "type": "string",
            "enum": ["cstats"]
        }
    },
    "required": ["command"]
}
```

### Response

HTML
