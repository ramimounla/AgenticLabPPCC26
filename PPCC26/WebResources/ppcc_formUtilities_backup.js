/**
 * Dynamics 365 CRM Form Utilities
 * 
 * @version 1.0
 */

/**
 * Setup conditional visibility of a section based on the value of a control field
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls the visibility
 * @param {string} tabName - The name of the tab containing the section
 * @param {string} sectionName - The name of the section to show/hide
 * @param {any|any[]|function} expectedValue - The value(s) that the control field should equal to make the section visible. Can be:
 *   - A single value
 *   - An array of values
 *   - A function that takes formContext and returns true/false for visibility
 *   - For lookup fields, use the GUID string (with or without braces)
 * 
 * Example usage:
 * // Simple conditional visibility
 * AI.FormUtilities.setupConditionalVisibility(
 *     formContext,
 *     "ai_agecategory",                    // Control field
 *     "tab_6Weeks",                       // Tab name
 *     "tab_6Weeks_sec_6WeekAdult",        // Section name
 *     100000004                           // Expected value: Adult
 * );
 * 
 * // Multiple values
 * AI.FormUtilities.setupConditionalVisibility(
 *     formContext,
 *     "ai_agecategory",                    // Control field
 *     "tab_6Weeks",                       // Tab name
 *     "tab_6Weeks_sec_ChildYouth",        // Section name
 *     [100000002, 100000003]              // Expected values: Child, Youth
 * );
 * 
 * // Lookup field with GUID
 * AI.FormUtilities.setupConditionalVisibility(
 *     formContext,
 *     "ai_servicecategoryid",             // Lookup control field
 *     "tab_Details",                      // Tab name
 *     "tab_Details_sec_SpecialSection",   // Section name
 *     "67c15493-12c8-f011-bbd3-00224814b22f" // Expected GUID value
 * );
 * 
 * // Multiple lookup GUIDs
 * AI.FormUtilities.setupConditionalVisibility(
 *     formContext,
 *     "ai_servicecategoryid",             // Lookup control field
 *     "tab_Details",                      // Tab name
 *     "tab_Details_sec_MultiSection",     // Section name
 *     [                                   // Expected GUID values
 *         "67c15493-12c8-f011-bbd3-00224814b22f",
 *         "caf1dc8a-12c8-f011-bbd3-00224814b22f"
 *     ]
 * );
 * 
 * // For polymorphic fields, use a custom function
 * AI.FormUtilities.setupConditionalVisibility(
 *     formContext,
 *     "regardingobjectid",                // Polymorphic control field
 *     "tab_Details",                      // Tab name
 *     "tab_Details_sec_ContactInfo",      // Section name
 *     function(formContext) {             // Custom function to determine visibility
 *         var regardingValue = formContext.getAttribute("regardingobjectid").getValue();
 *         if (regardingValue && regardingValue.length > 0) {
 *             var entityType = regardingValue[0].entityType;
 *             return entityType === "contact" || entityType === "account";
 *         }
 *         return false;
 *     }
 * );
 */
function setupConditionalVisibility(formContext, controlFieldName, tabName, sectionName, expectedValue) {
    try {
        // Get the control field 
        var controlField = formContext.getAttribute(controlFieldName);

        // Check if the field exists on the form
        if (controlField) {
            // Function to update the visibility
            var updateVisibility = function () {
                try {
                    var shouldBeVisible;

                    // Check if expectedValue is a function
                    if (typeof expectedValue === 'function') {
                        // Use the function to determine visibility
                        shouldBeVisible = expectedValue(formContext);
                    } else {
                        // Original logic - get the control field value
                        var controlValue = controlField.getValue();

                        // Special handling for lookup fields
                        if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                            // This is a lookup field - compare GUID values
                            var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, ''); // Remove braces and convert to lowercase

                            // Check if expectedValue is an array (multiple GUIDs to match)
                            if (Array.isArray(expectedValue)) {
                                shouldBeVisible = false;
                                // Check if the lookup ID is in the expected values array
                                for (var i = 0; i < expectedValue.length; i++) {
                                    var expectedId = expectedValue[i].toLowerCase().replace(/[{}]/g, '');
                                    if (lookupId === expectedId) {
                                        shouldBeVisible = true;
                                        break;
                                    }
                                }
                            } else {
                                // Single GUID comparison
                                var expectedId = expectedValue.toLowerCase().replace(/[{}]/g, '');
                                shouldBeVisible = lookupId === expectedId;
                            }
                        } else {
                            // Regular field handling (option sets, text, etc.)
                            // Check if expectedValue is an array (multiple values to match)
                            if (Array.isArray(expectedValue)) {
                                shouldBeVisible = false;
                                // Check if the control value is in the expected values array
                                for (var i = 0; i < expectedValue.length; i++) {
                                    if (controlValue === expectedValue[i]) {
                                        shouldBeVisible = true;
                                        break;
                                    }
                                }
                            } else {
                                // Default behavior - check for specific single value
                                shouldBeVisible = controlValue === expectedValue;
                            }
                        }
                    }

                    // Get the section
                    var section = formContext.ui.tabs.get(tabName).sections.get(sectionName);

                    // Check if the section exists
                    if (section) {
                        // Show section if condition is met, otherwise hide it
                        section.setVisible(shouldBeVisible);
                    } else {
                        console.log("Section " + sectionName + " not found on the form");
                    }
                } catch (innerError) {
                    console.error("Error in updateVisibility: " + innerError.message);
                }
            };

            // Add an event handler for when the control field changes
            // The handler will execute immediately due to the true parameter
            addSafeOnChange(formContext, controlFieldName, updateVisibility, true);

        } else {
            console.log("Field " + controlFieldName + " not found on the form");
        }
    } catch (error) {
        console.error("Error in setupConditionalVisibility: " + error.message);
    }
}

/**
 * Show or hide field(s) based on polymorphic lookup entity type
 * @param {object} formContext - The form context
 * @param {string} polymorphicFieldName - The name of the polymorphic lookup field (e.g., "regardingobjectid")
 * @param {string|string[]} targetFieldNames - The name(s) of the field(s) to show/hide
 * @param {string|string[]} entityTypes - The entity type(s) that should make the fields visible
 * 
 * Example usage:
 * // Show fields only for P2S cases
 * AI.FormUtilities.setupPolymorphicFieldVisibility(
 *     formContext,
 *     "regardingobjectid",                    // Polymorphic lookup field
 *     ["ai_supportneeds", "ai_consentprovided"], // Fields to show/hide
 *     "ai_pathwaytosettlementcase"            // Entity type to show for
 * );
 * 
 * // Show fields for multiple entity types
 * AI.FormUtilities.setupPolymorphicFieldVisibility(
 *     formContext,
 *     "regardingobjectid",                    // Polymorphic lookup field
 *     ["ai_field1", "ai_field2"],             // Fields to show/hide
 *     ["contact", "account"]                  // Multiple entity types
 * );
 */
function setupPolymorphicFieldVisibility(formContext, polymorphicFieldName, targetFieldNames, entityTypes) {
    try {
        // Get the polymorphic field
        var polymorphicField = formContext.getAttribute(polymorphicFieldName);

        // Check if the field exists on the form
        if (!polymorphicField) {
            console.log("Polymorphic field " + polymorphicFieldName + " not found on the form");
            return;
        }

        // Normalize targetFieldNames to always be an array
        var fieldNames = Array.isArray(targetFieldNames) ? targetFieldNames : [targetFieldNames];

        // Normalize entityTypes to always be an array
        var expectedEntityTypes = Array.isArray(entityTypes) ? entityTypes : [entityTypes];

        // Convert to lowercase for case-insensitive comparison
        for (var i = 0; i < expectedEntityTypes.length; i++) {
            expectedEntityTypes[i] = expectedEntityTypes[i].toLowerCase();
        }

        // Function to update the visibility
        var updateVisibility = function () {
            try {
                var shouldBeVisible = false;

                // Get the polymorphic field value
                var polymorphicValue = polymorphicField.getValue();

                if (polymorphicValue && polymorphicValue.length > 0) {
                    var entityType = polymorphicValue[0].entityType;
                    if (entityType) {
                        // Check if the entity type is in our expected types
                        var currentEntityType = entityType.toLowerCase();
                        for (var i = 0; i < expectedEntityTypes.length; i++) {
                            if (currentEntityType === expectedEntityTypes[i]) {
                                shouldBeVisible = true;
                                break;
                            }
                        }
                    }
                }

                // Update visibility for all target fields
                for (var i = 0; i < fieldNames.length; i++) {
                    var currentFieldName = fieldNames[i];
                    var targetControl = formContext.getControl(currentFieldName);

                    // Check if the target control exists
                    if (targetControl) {
                        // Show field if condition is met, otherwise hide it
                        targetControl.setVisible(shouldBeVisible);
                    } else {
                        console.log("Field control " + currentFieldName + " not found on the form");
                    }
                }
            } catch (innerError) {
                console.error("Error in updatePolymorphicFieldVisibility: " + innerError.message);
            }
        };

        // Add an event handler for when the polymorphic field changes
        addSafeOnChange(formContext, polymorphicFieldName, updateVisibility, true);

        console.log("Polymorphic field visibility setup complete for fields " + fieldNames.join(", ") +
            " based on " + polymorphicFieldName + " entity types: " + expectedEntityTypes.join(", "));

    } catch (error) {
        console.error("Error in setupPolymorphicFieldVisibility: " + error.message);
    }
}

/**
 * Clears a set of fields based on a control field change
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that triggers the clearing
 * @param {string[]} targetFields - Array of field names to clear when confirmed
 */
function clearFields(formContext, controlFieldName, targetFields) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Check if the field exists on the form
        if (!controlField) {
            console.log("Field " + controlFieldName + " not found on the form");
            return;
        }

        var clearAllFields = function () {
            // Clear all fields if they exist
            for (var i = 0; i < targetFields.length; i++) {
                var field = formContext.getAttribute(targetFields[i]);
                if (field) {
                    field.setValue(null);
                } else {
                    console.log("Target field " + targetFields[i] + " not found on the form");
                }
            }
        }

        // Add an event handler for when the control field changes
        // The handler will execute immediately due to the true parameter
        addSafeOnChange(formContext, controlFieldName, clearAllFields, false);
    } catch (error) {
        console.error("Error in clearFields: " + error.message);
    }
}

/**
 * Toggle the requirement level of target field(s) based on the value of a control field
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls the requirement
 * @param {string|string[]} targetFieldName - The name of the field(s) to make required/optional. Can be a single field name or an array of field names
 * @param {any|any[]} expectedValue - The value(s) that the control field should equal to make the target field required. Can be a single value or an array of values. For lookup fields, use the GUID string (with or without braces)
 * @param {boolean} [checkForAnyValue=false] - If true, checks if control field has any value instead of a specific value
 */
function setupConditionalRequirement(formContext, controlFieldName, targetFieldName, expectedValue, checkForAnyValue) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Normalize targetFieldName to always be an array
        var targetFieldNames = Array.isArray(targetFieldName) ? targetFieldName : [targetFieldName];

        // Get all target fields and validate they exist
        var targetFields = [];

        for (var i = 0; i < targetFieldNames.length; i++) {
            var field = formContext.getAttribute(targetFieldNames[i]);
            if (field) {
                targetFields.push(field);
            } else {
                console.log("Target field " + targetFieldNames[i] + " not found on the form");
            }
        }

        // Check if control field exists and we have at least one valid target field
        if (controlField && targetFields.length > 0) {
            // Function to update the requirement level
            var updateRequirementLevel = function () {
                var controlValue = controlField.getValue();
                var shouldBeRequired;

                if (checkForAnyValue === true) {
                    // Check if the field has any value (not null, undefined, or empty string)
                    shouldBeRequired = controlValue !== null &&
                        controlValue !== undefined &&
                        controlValue !== "";

                    // For arrays (like multiselect option sets or lookups), check if it has items
                    if (Array.isArray(controlValue)) {
                        shouldBeRequired = controlValue.length > 0;
                    }
                } else {
                    // Special handling for lookup fields
                    if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                        // This is a lookup field - compare GUID values
                        var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, ''); // Remove braces and convert to lowercase

                        if (Array.isArray(expectedValue)) {
                            shouldBeRequired = false;
                            // Check if the lookup ID is in the expected values array
                            for (var i = 0; i < expectedValue.length; i++) {
                                var expectedId = expectedValue[i].toLowerCase().replace(/[{}]/g, '');
                                if (lookupId === expectedId) {
                                    shouldBeRequired = true;
                                    break;
                                }
                            }
                        } else {
                            // Single GUID comparison
                            var expectedId = expectedValue.toLowerCase().replace(/[{}]/g, '');
                            shouldBeRequired = lookupId === expectedId;
                        }
                    } else {
                        // Default behavior - check for specific single value
                        // Regular field handling
                        // Check if expectedValue is an array (multiple values to match)
                        if (Array.isArray(expectedValue)) {
                            shouldBeRequired = false;
                            // Check if the control value is in the expected values array
                            for (var i = 0; i < expectedValue.length; i++) {
                                if (controlValue === expectedValue[i]) {
                                    shouldBeRequired = true;
                                    break;
                                }
                            }
                        } else {
                            // Default behavior - check for specific single value
                            shouldBeRequired = controlValue === expectedValue;
                        }
                    }
                }

                // Apply requirement level to all target fields
                for (var j = 0; j < targetFields.length; j++) {
                    if (shouldBeRequired) {
                        targetFields[j].setRequiredLevel("required");
                    } else {
                        targetFields[j].setRequiredLevel("none");
                    }
                }
            };

            // Add an event handler for when the control field changes
            controlField.addOnChange(updateRequirementLevel);

            // Initial check and setup
            updateRequirementLevel();

        } else {
            if (!controlField) {
                console.log("Control field " + controlFieldName + " not found on the form");
            }
            if (targetFields.length === 0) {
                console.log("No valid target fields found on the form");
            }
        }
    } catch (error) {
        console.error("Error in setupConditionalRequirement: " + error.message);
    }
}

/**
 * Toggle the requirement level of target field(s) based on date comparison with a control field
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the date field that controls the requirement
 * @param {string|string[]} targetFieldName - The name of the field(s) to make required/optional
 * @param {Date} compareDate - The date to compare against (usually new Date() for today)
 * @param {string} operator - Comparison operator: ">=", "<=", ">", "<", "=", "!="+
 * 
 * Examples of operator usage:
 * // Make field required if due date is today or later
 *   AI.FormUtilities.setupDateConditionalRequirement(
 *       formContext,
 *       "ai_12monthcheckduedate",     // Control field (date)
 *       "ai_someTargetField",         // Target field to make required
 *       new Date(),                   // Compare to today
 *       ">="                          // Operator: greater than or equal
 *   );
 * 
 *   // Make field required if date is exactly today
 *   AI.FormUtilities.setupDateConditionalRequirement(
 *       formContext,
 *       "ai_appointmentdate",
 *       "ai_appointmentNotes",
 *       new Date(),
 *       "="
 *   );
 */
function setupDateConditionalRequirement(formContext, controlFieldName, targetFieldName, compareDate, operator) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Normalize targetFieldName to always be an array
        var targetFieldNames = Array.isArray(targetFieldName) ? targetFieldName : [targetFieldName];

        // Get all target fields and validate they exist
        var targetFields = [];

        for (var i = 0; i < targetFieldNames.length; i++) {
            var field = formContext.getAttribute(targetFieldNames[i]);
            if (field) {
                targetFields.push(field);
            } else {
                console.log("Target field " + targetFieldNames[i] + " not found on the form");
            }
        }

        // Validate operator
        var validOperators = [">=", "<=", ">", "<", "=", "!="];
        if (validOperators.indexOf(operator) === -1) {
            console.error("Invalid operator '" + operator + "'. Valid operators: " + validOperators.join(", "));
            return;
        }

        if (!compareDate) {
            console.error("compareDate must be a valid Date object");
            return;
        }

        // Check if control field exists and we have at least one valid target field
        if (controlField && targetFields.length > 0) {
            // Function to update the requirement level
            var updateRequirementLevel = function () {
                var controlValue = controlField.getValue();
                var shouldBeRequired = false;

                // Check if control field has a date value
                if (controlValue) {
                    // Normalize dates to remove time component for accurate comparison
                    var controlDate = new Date(controlValue.getFullYear(), controlValue.getMonth(), controlValue.getDate());
                    var comparisonDate = new Date(compareDate.getFullYear(), compareDate.getMonth(), compareDate.getDate());

                    if (isNaN(controlDate.getTime()) || isNaN(comparisonDate.getTime())) {
                        shouldBeRequired = false;
                        return;
                    }

                    // Perform date comparison based on operator
                    switch (operator) {
                        case ">=":
                            shouldBeRequired = controlDate >= comparisonDate;
                            break;
                        case "<=":
                            shouldBeRequired = controlDate <= comparisonDate;
                            break;
                        case ">":
                            shouldBeRequired = controlDate > comparisonDate;
                            break;
                        case "<":
                            shouldBeRequired = controlDate < comparisonDate;
                            break;
                        case "=":
                            shouldBeRequired = controlDate.getTime() === comparisonDate.getTime();
                            break;
                        case "!=":
                            shouldBeRequired = controlDate.getTime() !== comparisonDate.getTime();
                            break;
                    }
                }

                // Apply requirement level to all target fields
                for (var j = 0; j < targetFields.length; j++) {
                    if (shouldBeRequired) {
                        targetFields[j].setRequiredLevel("required");
                    } else {
                        targetFields[j].setRequiredLevel("none");
                    }
                }
            };

            // Add an event handler for when the control field changes
            controlField.addOnChange(updateRequirementLevel);

            // Initial check and setup
            updateRequirementLevel();

        } else {
            if (!controlField) {
                console.log("Control field " + controlFieldName + " not found on the form");
            }
            if (targetFields.length === 0) {
                console.log("No valid target fields found on the form");
            }
        }
    } catch (error) {
        console.error("Error in setupDateConditionalRequirement: " + error.message);
    }
}

/**
 * Toggle the visibility of target field(s) based on date comparison with a control field
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the date field that controls the visibility
 * @param {string|string[]} targetFieldName - The name of the field(s) to show/hide
 * @param {Date} compareDate - The date to compare against (usually new Date() for today)
 * @param {string} operator - Comparison operator: ">=", "<=", ">", "<", "=", "!="
 * 
 * Examples of operator usage:
 * // Show field if due date is today or later
 *   AI.FormUtilities.setupDateConditionalVisibility(
 *       formContext,
 *       "ai_12monthcheckduedate",     // Control field (date)
 *       "ai_someTargetField",         // Target field to show/hide
 *       new Date(),                   // Compare to today
 *       ">="                          // Operator: greater than or equal
 *   );
 * 
 *   // Show field if date is exactly today
 *   AI.FormUtilities.setupDateConditionalVisibility(
 *       formContext,
 *       "ai_appointmentdate",
 *       "ai_appointmentNotes",
 *       new Date(),
 *       "="
 *   );
 */
function setupDateConditionalVisibility(formContext, controlFieldName, targetFieldName, compareDate, operator) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Normalize targetFieldName to always be an array
        var targetFieldNames = Array.isArray(targetFieldName) ? targetFieldName : [targetFieldName];

        // Get all target controls and validate they exist
        var targetControls = [];

        for (var i = 0; i < targetFieldNames.length; i++) {
            var control = formContext.getControl(targetFieldNames[i]);
            if (control) {
                targetControls.push(control);
            } else {
                console.log("Target field control " + targetFieldNames[i] + " not found on the form");
            }
        }

        // Validate operator
        var validOperators = [">=", "<=", ">", "<", "=", "!="];
        if (validOperators.indexOf(operator) === -1) {
            console.error("Invalid operator '" + operator + "'. Valid operators: " + validOperators.join(", "));
            return;
        }

        if (!compareDate) {
            console.error("compareDate must be a valid Date object");
            return;
        }

        // Check if control field exists and we have at least one valid target control
        if (controlField && targetControls.length > 0) {
            // Function to update the visibility
            var updateVisibility = function () {
                var controlValue = controlField.getValue();
                var shouldBeVisible = false;

                // Check if control field has a date value
                if (controlValue) {
                    // Normalize dates to remove time component for accurate comparison
                    var controlDate = new Date(controlValue.getFullYear(), controlValue.getMonth(), controlValue.getDate());
                    var comparisonDate = new Date(compareDate.getFullYear(), compareDate.getMonth(), compareDate.getDate());

                    if (isNaN(controlDate.getTime()) || isNaN(comparisonDate.getTime())) {
                        shouldBeVisible = false;
                        return;
                    }

                    // Perform date comparison based on operator
                    switch (operator) {
                        case ">=":
                            shouldBeVisible = controlDate >= comparisonDate;
                            break;
                        case "<=":
                            shouldBeVisible = controlDate <= comparisonDate;
                            break;
                        case ">":
                            shouldBeVisible = controlDate > comparisonDate;
                            break;
                        case "<":
                            shouldBeVisible = controlDate < comparisonDate;
                            break;
                        case "=":
                            shouldBeVisible = controlDate.getTime() === comparisonDate.getTime();
                            break;
                        case "!=":
                            shouldBeVisible = controlDate.getTime() !== comparisonDate.getTime();
                            break;
                    }
                }

                // Apply visibility to all target controls
                for (var j = 0; j < targetControls.length; j++) {
                    targetControls[j].setVisible(shouldBeVisible);
                }
            };

            // Add an event handler for when the control field changes
            controlField.addOnChange(updateVisibility);

            // Initial check and setup
            updateVisibility();

        } else {
            if (!controlField) {
                console.log("Control field " + controlFieldName + " not found on the form");
            }
            if (targetControls.length === 0) {
                console.log("No valid target field controls found on the form");
            }
        }
    } catch (error) {
        console.error("Error in setupDateConditionalVisibility: " + error.message);
    }
}

/**
 * Sets a specific value in a target field when a control field matches an expected value
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls when to set the value
 * @param {string} targetFieldName - The name of the field to set the value on
 * @param {any} expectedValue - The value that the control field should equal to trigger setting the target value
 * @param {any} targetValue - The value to set in the target field when the condition is met
 */
function setupFieldValueOnCondition(formContext, controlFieldName, targetFieldName, expectedValue, targetValue) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Get the target field
        var targetField = formContext.getAttribute(targetFieldName);

        // Check if both fields exist
        if (!controlField || !targetField) {
            console.log("One or both fields (" + controlFieldName + ", " + targetFieldName + ") not found on the form");
            return;
        }

        // Function to update the requirement level
        var updateFieldValue = function () {
            var controlValue = controlField.getValue();
            if (controlValue === expectedValue) {
                targetField.setValue(targetValue);
                // Manually fire the onChange event for the target field
                targetField.fireOnChange();
            }
        };

        // Add an event handler for when the control field changes
        controlField.addOnChange(updateFieldValue);


    } catch (error) {
        console.error("Error in setupFieldValueOnCondition: " + error.message);
    }
}

/**
 * Copies the value from a source field to a target field when a control field matches an expected value
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls when to copy the value
 * @param {string} sourceFieldName - The name of the field to copy the value from
 * @param {string} targetFieldName - The name of the field to copy the value to
 * @param {any} expectedValue - The value that the control field should equal to trigger copying
 */
function setupCopyFieldValueOnCondition(formContext, controlFieldName, sourceFieldName, targetFieldName, expectedValue) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Get the source field
        var sourceField = formContext.getAttribute(sourceFieldName);

        // Get the target field
        var targetField = formContext.getAttribute(targetFieldName);

        // Check if all fields exist
        if (!controlField || !sourceField || !targetField) {
            console.log("One or more fields (" + controlFieldName + ", " + sourceFieldName + ", " + targetFieldName + ") not found on the form");
            return;
        }

        // Function to copy the field value
        var copyFieldValue = function () {
            var controlValue = controlField.getValue();
            if (controlValue === expectedValue) {
                var sourceValue = sourceField.getValue();
                targetField.setValue(sourceValue);
                // Manually fire the onChange event for the target field
                targetField.fireOnChange();
            }
        };

        // Add an event handler for when the control field changes
        controlField.addOnChange(copyFieldValue);

        // Also monitor the source field for changes when the condition is met
        var copyOnSourceChange = function () {
            var controlValue = controlField.getValue();
            if (controlValue === expectedValue) {
                var sourceValue = sourceField.getValue();
                targetField.setValue(sourceValue);
                // Manually fire the onChange event for the target field
                targetField.fireOnChange();
            }
        };

        // Add an event handler for when the source field changes
        sourceField.addOnChange(copyOnSourceChange);

    } catch (error) {
        console.error("Error in setupCopyFieldValueOnCondition: " + error.message);
    }
}

/**
 * Setup conditional requirement with multiple control fields using AND logic
 * @param {object} formContext - The form context
 * @param {object[]} conditions - Array of condition objects. Each object can be:
 *   Field-based condition:
 *   - fieldName: string - The name of the control field
 *   - expectedValue: any|any[] - The expected value(s) for this field
 *   - checkForAnyValue: boolean - If true, checks if field has any value instead of specific value
 *   
 *   Date comparison condition:
 *   - fieldName: string - The name of the date field
 *   - compareDate: Date - The date to compare against (usually new Date() for today)
 *   - operator: string - Comparison operator: ">=", "<=", ">", "<", "=", "!="
 *   
 *   Custom function condition:
 *   - customValidation: function - Function that takes formContext and returns boolean
 *   - watchFields: string[] - Array of field names to watch for changes (optional)
 * 
 * @param {string|string[]} targetFieldName - The name of the field(s) to make required/optional
 * 
 * Example conditions:
 * [
 *   { fieldName: "ai_clienttype", expectedValue: 10000000, checkForAnyValue: false },
 *   { fieldName: "ai_6monthcheckduedate", compareDate: new Date(), operator: "<" },
 *   { fieldName: "ai_orientationattendeddate", expectedValue: null, checkForAnyValue: false }
 * ]
 */
function setupMultiFieldConditionalRequirement(formContext, conditions, targetFieldName) {
    try {
        // Validate conditions parameter
        if (!Array.isArray(conditions) || conditions.length === 0) {
            console.log("Conditions parameter must be a non-empty array");
            return;
        }

        // Normalize targetFieldName to always be an array
        var targetFieldNames = Array.isArray(targetFieldName) ? targetFieldName : [targetFieldName];

        // Get all target fields and validate they exist
        var targetFields = [];
        for (var i = 0; i < targetFieldNames.length; i++) {
            var field = formContext.getAttribute(targetFieldNames[i]);
            if (field) {
                targetFields.push(field);
            } else {
                console.log("Target field " + targetFieldNames[i] + " not found on the form");
            }
        }

        // Get all control fields and validate they exist
        var controlFields = [];
        var dateConditions = [];
        var customConditions = [];

        for (var i = 0; i < conditions.length; i++) {
            var condition = conditions[i];

            // Check if this is a custom function condition
            if (condition.customValidation && typeof condition.customValidation === 'function') {
                customConditions.push({
                    validationFunction: condition.customValidation,
                    watchFields: condition.watchFields || []
                });
            }
            // Check if this is a date comparison condition
            else if (condition.compareDate && condition.operator) {
                if (!condition.fieldName) {
                    console.log("Date condition at index " + i + " is missing fieldName");
                    continue;
                }

                var validOperators = [">=", "<=", ">", "<", "=", "!="];
                if (validOperators.indexOf(condition.operator) === -1) {
                    console.error("Invalid operator '" + condition.operator + "' at index " + i + ". Valid operators: " + validOperators.join(", "));
                    continue;
                }

                var dateField = formContext.getAttribute(condition.fieldName);
                if (dateField) {
                    dateConditions.push({
                        field: dateField,
                        compareDate: condition.compareDate,
                        operator: condition.operator,
                        fieldName: condition.fieldName
                    });
                } else {
                    console.log("Date field " + condition.fieldName + " not found on the form");
                }
            }
            // Regular field-based condition
            else {
                if (!condition.fieldName) {
                    console.log("Condition at index " + i + " is missing fieldName");
                    continue;
                }

                var controlField = formContext.getAttribute(condition.fieldName);
                if (controlField) {
                    controlFields.push({
                        field: controlField,
                        expectedValue: condition.expectedValue,
                        checkForAnyValue: condition.checkForAnyValue || false,
                        fieldName: condition.fieldName
                    });
                } else {
                    console.log("Control field " + condition.fieldName + " not found on the form");
                }
            }
        }

        // Check if we have valid conditions
        if (controlFields.length === 0 && dateConditions.length === 0 && customConditions.length === 0) {
            console.log("No valid control fields, date conditions, or custom conditions found");
            return;
        }

        if (targetFields.length === 0) {
            console.log("No valid target fields found");
            return;
        }

        // Function to evaluate all conditions (AND logic)
        var evaluateAllConditions = function () {
            var allConditionsMet = true;

            // Evaluate field-based conditions
            for (var i = 0; i < controlFields.length; i++) {
                var controlFieldData = controlFields[i];
                var controlValue = controlFieldData.field.getValue();
                var conditionMet = false;

                if (controlFieldData.checkForAnyValue === true) {
                    // Check if the field has any value (not null, undefined, or empty string)
                    conditionMet = controlValue !== null &&
                        controlValue !== undefined &&
                        controlValue !== "";

                    // For arrays (like multiselect option sets or lookups), check if it has items
                    if (Array.isArray(controlValue)) {
                        conditionMet = controlValue.length > 0;
                    }
                } else {
                    // Special handling for lookup fields
                    if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                        // This is a lookup field - compare GUID values
                        var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, '');

                        if (Array.isArray(controlFieldData.expectedValue)) {
                            // Check if the lookup ID is in the expected values array
                            for (var j = 0; j < controlFieldData.expectedValue.length; j++) {
                                var expectedId = controlFieldData.expectedValue[j].toLowerCase().replace(/[{}]/g, '');
                                if (lookupId === expectedId) {
                                    conditionMet = true;
                                    break;
                                }
                            }
                        } else {
                            // Single GUID comparison
                            var expectedId = controlFieldData.expectedValue.toLowerCase().replace(/[{}]/g, '');
                            conditionMet = lookupId === expectedId;
                        }
                    } else {
                        // Regular field handling
                        if (Array.isArray(controlFieldData.expectedValue)) {
                            // Check if the control value is in the expected values array
                            for (var j = 0; j < controlFieldData.expectedValue.length; j++) {
                                if (controlValue === controlFieldData.expectedValue[j]) {
                                    conditionMet = true;
                                    break;
                                }
                            }
                        } else {
                            // Default behavior - check for specific single value
                            conditionMet = controlValue === controlFieldData.expectedValue;
                        }
                    }
                }

                // If any condition is not met, break early (AND logic)
                if (!conditionMet) {
                    allConditionsMet = false;
                    break;
                }
            }

            // Evaluate date comparison conditions (only if field conditions passed)
            if (allConditionsMet) {
                for (var i = 0; i < dateConditions.length; i++) {
                    var dateCondition = dateConditions[i];
                    var dateValue = dateCondition.field.getValue();
                    var conditionMet = false;

                    if (dateValue) {
                        // Normalize dates to remove time component for accurate comparison
                        var controlDate = new Date(dateValue.getFullYear(), dateValue.getMonth(), dateValue.getDate());
                        var comparisonDate = new Date(dateCondition.compareDate.getFullYear(), dateCondition.compareDate.getMonth(), dateCondition.compareDate.getDate());

                        if (!isNaN(controlDate.getTime()) && !isNaN(comparisonDate.getTime())) {
                            // Perform date comparison based on operator
                            switch (dateCondition.operator) {
                                case ">=":
                                    conditionMet = controlDate >= comparisonDate;
                                    break;
                                case "<=":
                                    conditionMet = controlDate <= comparisonDate;
                                    break;
                                case ">":
                                    conditionMet = controlDate > comparisonDate;
                                    break;
                                case "<":
                                    conditionMet = controlDate < comparisonDate;
                                    break;
                                case "=":
                                    conditionMet = controlDate.getTime() === comparisonDate.getTime();
                                    break;
                                case "!=":
                                    conditionMet = controlDate.getTime() !== comparisonDate.getTime();
                                    break;
                            }
                        }
                    }

                    // If any date condition is not met, break early (AND logic)
                    if (!conditionMet) {
                        allConditionsMet = false;
                        break;
                    }
                }
            }

            // Evaluate custom function conditions (only if previous conditions passed)
            if (allConditionsMet) {
                for (var i = 0; i < customConditions.length; i++) {
                    var customCondition = customConditions[i];
                    try {
                        var customResult = customCondition.validationFunction(formContext);
                        if (!customResult) {
                            allConditionsMet = false;
                            break;
                        }
                    } catch (error) {
                        console.error("Error in custom validation function: " + error.message);
                        allConditionsMet = false;
                        break;
                    }
                }
            }

            // Apply requirement level to all target fields
            for (var k = 0; k < targetFields.length; k++) {
                if (allConditionsMet) {
                    targetFields[k].setRequiredLevel("required");
                } else {
                    targetFields[k].setRequiredLevel("none");
                }
            }
        };

        // Add event handlers for all control fields
        for (var i = 0; i < controlFields.length; i++) {
            controlFields[i].field.addOnChange(evaluateAllConditions);
        }

        // Add event handlers for all date fields
        for (var i = 0; i < dateConditions.length; i++) {
            dateConditions[i].field.addOnChange(evaluateAllConditions);
        }

        // Add event handlers for custom condition watch fields
        for (var i = 0; i < customConditions.length; i++) {
            var customCondition = customConditions[i];
            for (var j = 0; j < customCondition.watchFields.length; j++) {
                var watchFieldName = customCondition.watchFields[j];
                var watchField = formContext.getAttribute(watchFieldName);
                if (watchField) {
                    watchField.addOnChange(evaluateAllConditions);
                }
            }
        }

        // Initial evaluation
        evaluateAllConditions();

    } catch (error) {
        console.error("Error in setupMultiFieldConditionalRequirement: " + error.message);
    }
}

/**
 * Setup conditional visibility of a section based on multiple field conditions using AND logic
 * @param {object} formContext - The form context
 * @param {object[]} conditions - Array of condition objects. Each object can be:
 *   Field-based condition:
 *   - fieldName: string - The name of the control field
 *   - expectedValue: any|any[] - The expected value(s) for this field
 *   - checkForAnyValue: boolean - If true, checks if field has any value instead of specific value
 *   
 *   Custom function condition:
 *   - customValidation: function - Function that takes formContext and returns boolean
 *   - watchFields: string[] - Array of field names to watch for changes (optional)
 * 
 * @param {string} tabName - The name of the tab containing the section
 * @param {string} sectionName - The name of the section to show/hide
 * 
 * Example conditions:
 * [
 *   { fieldName: "ai_agecategory", expectedValue: 100000003, checkForAnyValue: false },
 *   { fieldName: "ai_status", expectedValue: [100000001, 100000002], checkForAnyValue: false },
 *   { customValidation: function(formContext) { return someLogic(); }, watchFields: ["ai_journey"] }
 * ]
 */
function setupMultiFieldConditionalVisibility(formContext, conditions, tabName, sectionName) {
    try {
        // Validate conditions parameter
        if (!Array.isArray(conditions) || conditions.length === 0) {
            console.log("Conditions parameter must be a non-empty array");
            return;
        }

        // Validate required parameters
        if (!tabName || !sectionName) {
            console.log("tabName and sectionName are required parameters");
            return;
        }

        // Get all control fields and validate they exist
        var controlFields = [];
        var customConditions = [];

        for (var i = 0; i < conditions.length; i++) {
            var condition = conditions[i];

            // Check if this is a custom function condition
            if (condition.customValidation && typeof condition.customValidation === 'function') {
                customConditions.push({
                    validationFunction: condition.customValidation,
                    watchFields: condition.watchFields || []
                });
            } else {
                // Regular field-based condition
                if (!condition.fieldName) {
                    console.log("Condition at index " + i + " is missing fieldName");
                    continue;
                }

                var controlField = formContext.getAttribute(condition.fieldName);
                if (controlField) {
                    controlFields.push({
                        field: controlField,
                        expectedValue: condition.expectedValue,
                        checkForAnyValue: condition.checkForAnyValue || false,
                        fieldName: condition.fieldName
                    });
                } else {
                    console.log("Control field " + condition.fieldName + " not found on the form");
                }
            }
        }

        // Check if we have valid conditions
        if (controlFields.length === 0 && customConditions.length === 0) {
            console.log("No valid control fields or custom conditions found");
            return;
        }

        // Function to evaluate all conditions (AND logic)
        var evaluateAllConditions = function () {
            var allConditionsMet = true;

            // Evaluate field-based conditions
            for (var i = 0; i < controlFields.length; i++) {
                var controlFieldData = controlFields[i];
                var controlValue = controlFieldData.field.getValue();
                var conditionMet = false;

                if (controlFieldData.checkForAnyValue === true) {
                    // Check if the field has any value (not null, undefined, or empty string)
                    conditionMet = controlValue !== null &&
                        controlValue !== undefined &&
                        controlValue !== "";

                    // For arrays (like multiselect option sets or lookups), check if it has items
                    if (Array.isArray(controlValue)) {
                        conditionMet = controlValue.length > 0;
                    }
                } else {
                    // Special handling for lookup fields
                    if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                        // This is a lookup field - compare GUID values
                        var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, '');

                        if (Array.isArray(controlFieldData.expectedValue)) {
                            // Check if the lookup ID is in the expected values array
                            for (var j = 0; j < controlFieldData.expectedValue.length; j++) {
                                var expectedId = controlFieldData.expectedValue[j].toLowerCase().replace(/[{}]/g, '');
                                if (lookupId === expectedId) {
                                    conditionMet = true;
                                    break;
                                }
                            }
                        } else {
                            // Single GUID comparison
                            var expectedId = controlFieldData.expectedValue.toLowerCase().replace(/[{}]/g, '');
                            conditionMet = lookupId === expectedId;
                        }
                    } else {
                        // Regular field handling
                        if (Array.isArray(controlFieldData.expectedValue)) {
                            // Check if the control value is in the expected values array
                            for (var j = 0; j < controlFieldData.expectedValue.length; j++) {
                                if (controlValue === controlFieldData.expectedValue[j]) {
                                    conditionMet = true;
                                    break;
                                }
                            }
                        } else {
                            // Default behavior - check for specific single value
                            conditionMet = controlValue === controlFieldData.expectedValue;
                        }
                    }
                }

                // If any condition is not met, break early (AND logic)
                if (!conditionMet) {
                    allConditionsMet = false;
                    break;
                }
            }

            // Evaluate custom function conditions (only if field conditions passed)
            if (allConditionsMet) {
                for (var i = 0; i < customConditions.length; i++) {
                    var customCondition = customConditions[i];
                    try {
                        var customResult = customCondition.validationFunction(formContext);
                        if (!customResult) {
                            allConditionsMet = false;
                            break;
                        }
                    } catch (error) {
                        console.error("Error in custom validation function: " + error.message);
                        allConditionsMet = false;
                        break;
                    }
                }
            }

            // Apply visibility to the section
            try {
                var section = formContext.ui.tabs.get(tabName).sections.get(sectionName);
                if (section) {
                    section.setVisible(allConditionsMet);
                } else {
                    console.log("Section " + sectionName + " not found in tab " + tabName);
                }
            } catch (sectionError) {
                console.error("Error setting section visibility: " + sectionError.message);
            }
        };

        // Add event handlers for all control fields
        for (var i = 0; i < controlFields.length; i++) {
            controlFields[i].field.addOnChange(evaluateAllConditions);
        }

        // Add event handlers for custom condition watch fields
        for (var i = 0; i < customConditions.length; i++) {
            var customCondition = customConditions[i];
            for (var j = 0; j < customCondition.watchFields.length; j++) {
                var watchFieldName = customCondition.watchFields[j];
                var watchField = formContext.getAttribute(watchFieldName);
                if (watchField) {
                    watchField.addOnChange(evaluateAllConditions);
                }
            }
        }

        // Initial evaluation
        evaluateAllConditions();

    } catch (error) {
        console.error("Error in setupMultiFieldConditionalVisibility: " + error.message);
    }
}


/**
 * Show or hide a tab based on the value of a control field
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls the visibility
 * @param {string} tabName - The name of the tab to show/hide
 * @param {any} expectedValue - The value that the control field should equal to make the tab visible. For lookup fields, use the GUID string (with or without braces)
 */
function setupTabVisibility(formContext, controlFieldName, tabName, expectedValue) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Check if the field exists on the form
        if (controlField) {
            // Function to update the visibility
            var updateVisibility = function () {
                try {
                    // Get the control field value
                    var controlValue = controlField.getValue();
                    var shouldBeVisible;

                    // Special handling for lookup fields
                    if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                        // This is a lookup field - compare GUID values
                        var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, ''); // Remove braces and convert to lowercase
                        var expectedId = expectedValue.toLowerCase().replace(/[{}]/g, '');
                        shouldBeVisible = lookupId === expectedId;
                    } else {
                        // Regular field handling - direct comparison
                        shouldBeVisible = controlValue === expectedValue;
                    }

                    // Get the tab
                    var tab = formContext.ui.tabs.get(tabName);

                    // Check if the tab exists
                    if (tab) {
                        // Show tab if condition is met, otherwise hide it
                        tab.setVisible(shouldBeVisible);
                    } else {
                        console.log("Tab " + tabName + " not found on the form");
                    }
                } catch (innerError) {
                    console.error("Error in updateTabVisibility: " + innerError.message);
                }
            };

            // Add an event handler for when the control field changes
            // The handler will execute immediately due to the true parameter
            addSafeOnChange(formContext, controlFieldName, updateVisibility, true);

        } else {
            console.log("Field " + controlFieldName + " not found on the form");
        }
    } catch (error) {
        console.error("Error in setupTabVisibility: " + error.message);
    }
}

/**
 * Show or hide a field (or multiple fields) based on the value of a control field
 * Also automatically makes hidden fields optional to prevent validation issues
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls the visibility
 * @param {string|string[]} targetFieldName - The name of the field(s) to show/hide. Can be a single field name or an array of field names
 * @param {any|any[]} expectedValue - The value(s) that the control field should equal to make the target field(s) visible. Can be a single value or an array of values. For lookup fields, use the GUID string (with or without braces)
 * @param {boolean} [checkForAnyValue=false] - If true, checks if control field has any value instead of a specific value
 */
function setupFieldVisibility(formContext, controlFieldName, targetFieldName, expectedValue, checkForAnyValue) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Check if the field exists on the form
        if (controlField) {
            // Normalize targetFieldName to always be an array
            var targetFieldNames = Array.isArray(targetFieldName) ? targetFieldName : [targetFieldName];

            // Function to update the visibility
            var updateVisibility = function () {
                try {
                    // Get the control field value
                    var controlValue = controlField.getValue();
                    var shouldBeVisible;

                    if (checkForAnyValue === true) {
                        // Check if the field has any value (not null, undefined, or empty string)
                        shouldBeVisible = controlValue !== null &&
                            controlValue !== undefined &&
                            controlValue !== "";

                        // For arrays (like multiselect option sets or lookups), check if it has items
                        if (Array.isArray(controlValue)) {
                            shouldBeVisible = controlValue.length > 0;
                        }
                    } else {
                        // Special handling for lookup fields
                        if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                            // This is a lookup field - compare GUID values
                            var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, '');

                            // Check if expectedValue is an array (multiple GUIDs to match)
                            if (Array.isArray(expectedValue)) {
                                shouldBeVisible = false;
                                // Check if the lookup ID is in the expected values array
                                for (var i = 0; i < expectedValue.length; i++) {
                                    var expectedId = expectedValue[i].toLowerCase().replace(/[{}]/g, '');
                                    if (lookupId === expectedId) {
                                        shouldBeVisible = true;
                                        break;
                                    }
                                }
                            } else {
                                // Single GUID comparison
                                var expectedId = expectedValue.toLowerCase().replace(/[{}]/g, '');
                                shouldBeVisible = lookupId === expectedId;
                            }
                        } else {
                            // Regular field handling (option sets, text, etc.)
                            // Check if expectedValue is an array (multiple values to match)
                            if (Array.isArray(expectedValue)) {
                                shouldBeVisible = false;
                                // Check if the control value is in the expected values array
                                for (var i = 0; i < expectedValue.length; i++) {
                                    if (controlValue === expectedValue[i]) {
                                        shouldBeVisible = true;
                                        break;
                                    }
                                }
                            } else {
                                // Default behavior - check for specific single value
                                shouldBeVisible = controlValue === expectedValue;
                            }
                        }
                    }

                    // Update visibility and requirement level for all target fields
                    for (var i = 0; i < targetFieldNames.length; i++) {
                        var currentTargetFieldName = targetFieldNames[i];
                        var targetControl = formContext.getControl(currentTargetFieldName);
                        var targetAttribute = formContext.getAttribute(currentTargetFieldName);

                        // Check if the target control exists
                        if (targetControl) {
                            // Show field if condition is met, otherwise hide it
                            targetControl.setVisible(shouldBeVisible);
                        } else {
                            console.log("Field control " + currentTargetFieldName + " not found on the form");
                        }

                        // Also manage the requirement level - make hidden fields optional to prevent validation issues
                        if (targetAttribute) {
                            if (!shouldBeVisible) {
                                // Store the original requirement level before making it optional
                                if (targetAttribute._originalRequiredLevel === undefined) {
                                    targetAttribute._originalRequiredLevel = targetAttribute.getRequiredLevel();
                                }
                                // Make hidden fields optional to prevent validation errors
                                targetAttribute.setRequiredLevel("none");
                            } else {
                                // If field is becoming visible, restore original requirement level if it was stored
                                if (targetAttribute._originalRequiredLevel !== undefined) {
                                    targetAttribute.setRequiredLevel(targetAttribute._originalRequiredLevel);
                                    // Clear the stored value
                                    targetAttribute._originalRequiredLevel = undefined;
                                }
                            }
                        } else {
                            console.log("Field attribute " + currentTargetFieldName + " not found on the form");
                        }
                    }
                } catch (innerError) {
                    console.error("Error in updateFieldVisibility: " + innerError.message);
                }
            };

            // Add an event handler for when the control field changes
            // The handler will execute immediately due to the true parameter
            addSafeOnChange(formContext, controlFieldName, updateVisibility, true);

        } else {
            console.log("Field " + controlFieldName + " not found on the form");
        }
    } catch (error) {
        console.error("Error in setupFieldVisibility: " + error.message);
    }
}

/**
 * Safely adds an event handler to a field, preserving any existing handlers
 * @param {object} formContext - The form context
 * @param {string} fieldName - The name of the field to add the event handler to
 * @param {Function} eventHandler - The event handler function to add
 * @param {boolean} [executeImmediately=true] - Whether to execute the handler immediately
 * @returns {boolean} - True if the handler was added successfully, false otherwise
 */
function addSafeOnChange(formContext, fieldName, eventHandler, executeImmediately) {
    try {
        // Default executeImmediately to true if not specified
        if (executeImmediately === undefined) {
            executeImmediately = true;
        }

        // Get the attribute
        var attribute = formContext.getAttribute(fieldName);

        // Check if the attribute exists
        if (attribute) {
            // Store the original event handlers if not already stored
            if (!attribute._onChangeHandlers) {
                // Keep track of all handlers
                attribute._onChangeHandlers = [];

                // Create the manager function that executes all handlers
                var multipleChangeHandlerManager = function () {
                    for (var i = 0; i < attribute._onChangeHandlers.length; i++) {
                        try {
                            attribute._onChangeHandlers[i]();
                        } catch (error) {
                            console.error("Error in event handler: " + error.message);
                        }
                    }
                };

                // Register the manager with the field
                attribute.addOnChange(multipleChangeHandlerManager);
            }

            // Add the new handler to our collection
            attribute._onChangeHandlers.push(eventHandler);

            // Execute immediately if requested
            if (executeImmediately) {
                eventHandler();
            }

            return true;
        } else {
            console.log("Field " + fieldName + " not found on the form");
            return false;
        }
    } catch (error) {
        console.error("Error in addSafeOnChange: " + error.message);
        return false;
    }
}

/**
 * Setup conditional visibility/requirement based on a custom validation function
 * @param {object} formContext - The form context
 * @param {string|string[]} watchFields - Field name(s) to watch for changes that should trigger re-evaluation
 * @param {function} validationFunction - Function that takes formContext and returns true/false
 * @param {string|string[]} targetFieldName - The name of the field(s) to affect
 * @param {string} action - Action to perform: 'visibility', 'requirement', 'sectionVisibility'
 * @param {string} [tabName] - Tab name (required for sectionVisibility)
 * @param {string} [sectionName] - Section name (required for sectionVisibility)
 */
function setupFunctionBasedConditional(formContext, watchFields, validationFunction, targetFieldName, action, tabName, sectionName) {
    try {
        // Validate parameters
        if (typeof validationFunction !== 'function') {
            console.error("validationFunction must be a function");
            return;
        }

        var validActions = ['visibility', 'requirement', 'sectionVisibility'];
        if (validActions.indexOf(action) === -1) {
            console.error("Action must be one of: " + validActions.join(', '));
            return;
        }

        if (action === 'sectionVisibility' && (!tabName || !sectionName)) {
            console.error("tabName and sectionName are required for sectionVisibility action");
            return;
        }

        // Normalize watchFields to array
        var watchFieldNames = Array.isArray(watchFields) ? watchFields : [watchFields];

        // Get target fields/controls for visibility/requirement actions
        var targetFields = [];
        var targetControls = [];

        if (action === 'visibility' || action === 'requirement') {
            var targetFieldNames = Array.isArray(targetFieldName) ? targetFieldName : [targetFieldName];

            for (var i = 0; i < targetFieldNames.length; i++) {
                if (action === 'visibility') {
                    var control = formContext.getControl(targetFieldNames[i]);
                    if (control) {
                        targetControls.push(control);
                    } else {
                        console.log("Control '" + targetFieldNames[i] + "' not found on form");
                    }
                } else if (action === 'requirement') {
                    var field = formContext.getAttribute(targetFieldNames[i]);
                    if (field) {
                        targetFields.push(field);
                    } else {
                        console.log("Field '" + targetFieldNames[i] + "' not found on form");
                    }
                }
            }
        }

        // Function to evaluate the custom validation
        var evaluateCondition = function () {
            try {
                // Call the custom validation function
                var result = validationFunction(formContext);

                // Ensure result is boolean
                var boolResult = Boolean(result);

                // Apply the result based on action type
                if (action === 'visibility') {
                    for (var i = 0; i < targetControls.length; i++) {
                        targetControls[i].setVisible(boolResult);
                    }
                } else if (action === 'requirement') {
                    for (var i = 0; i < targetFields.length; i++) {
                        targetFields[i].setRequiredLevel(boolResult ? "required" : "none");
                    }
                } else if (action === 'sectionVisibility') {
                    var section = formContext.ui.tabs.get(tabName).sections.get(sectionName);
                    if (section) {
                        section.setVisible(boolResult);
                    } else {
                        console.log("Section '" + sectionName + "' not found in tab '" + tabName + "'");
                    }
                }

            } catch (error) {
                console.error("Error in custom validation function: " + error.message);
            }
        };

        // Add event handlers to all watch fields
        for (var i = 0; i < watchFieldNames.length; i++) {
            addSafeOnChange(formContext, watchFieldNames[i], evaluateCondition, false);
        }

        // Initial evaluation
        evaluateCondition();

    } catch (error) {
        console.error("Error in setupFunctionBasedConditional: " + error.message);
    }
}

/**
 * Setup conditional lookup view based on control field value
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the field that controls which view to use
 * @param {string} targetLookupFieldName - The name of the lookup field to change the view for
 * @param {string} viewGuidWhenHasValue - GUID of the view to use when control field has a value
 * @param {string} defaultViewGuid - GUID of the view to use when control field is empty (DEPRECATED - no longer used)
 */
function setupConditionalLookupView(formContext, controlFieldName, targetLookupFieldName, viewGuidWhenHasValue, defaultViewGuid) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Get the target lookup control
        var targetLookupControl = formContext.getControl(targetLookupFieldName);

        // Validate that both fields exist
        if (!controlField) {
            console.log("Control field " + controlFieldName + " not found on the form");
            return;
        }

        if (!targetLookupControl) {
            console.log("Target lookup control " + targetLookupFieldName + " not found on the form");
            return;
        }

        // Function to update the lookup view
        var updateLookupView = function () {
            try {
                var controlValue = controlField.getValue();
                
                // Check if control field has a value
                if (controlValue !== null && controlValue !== undefined && controlValue !== ""
                    && (!Array.isArray(controlValue) || controlValue.length > 0)) {
                    targetLookupControl.setDefaultView(viewGuidWhenHasValue);
                }
            } catch (innerError) {
                console.error("Error in updateConditionalLookupView: " + innerError.message);
            }
        };

        // Add an event handler for when the control field changes
        addSafeOnChange(formContext, controlFieldName, updateLookupView, true);

    } catch (error) {
        console.error("Error in setupConditionalLookupView: " + error.message);
    }
}

/**
 * Rename a tab based on a lookup field's GUID value
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The name of the lookup field that controls the tab name
 * @param {string} tabName - The name of the tab to rename
 * @param {string} expectedValue - The GUID value that the lookup field should equal to trigger renaming
 * @param {string} newTabName - The new name for the tab when condition is met
 * @param {string} [defaultTabName] - The default tab name when condition is not met (optional)
 * 
 * Example usage:
 * // Rename tab based on lookup field value
 * AI.FormUtilities.setupConditionalTabRename(
 *     formContext,
 *     "ai_servicecategoryid",              // Lookup control field
 *     "tab_Details",                       // Tab name
 *     "67c15493-12c8-f011-bbd3-00224814b22f", // Expected GUID value
 *     "P2S Details",                       // New tab name when condition met
 *     "Details"                            // Default tab name when condition not met
 * );
 */
function setupConditionalTabRename(formContext, controlFieldName, tabName, expectedValue, newTabName) {
    try {
        // Get the control field
        var controlField = formContext.getAttribute(controlFieldName);

        // Check if the field exists on the form
        if (!controlField) {
            console.log("Field " + controlFieldName + " not found on the form");
            return;
        }

        // Get the tab
        var tab = formContext.ui.tabs.get(tabName);
        if (!tab) {
            console.log("Tab " + tabName + " not found on the form");
            return;
        }

        // Store original tab name if defaultTabName not provided
        var originalTabName = tab.getLabel();

        // Function to update the tab name
        // Function to update the tab name
        var updateTabName = function () {
            try {
                // Get the control field value
                var controlValue = controlField.getValue();
                var tabNameToUse = originalTabName; // Default

                // Check if this is a lookup field with a value FIRST
                if (Array.isArray(controlValue) && controlValue.length > 0 && controlValue[0].id) {
                    // THEN extract and clean the GUIDs
                    var lookupId = controlValue[0].id.toLowerCase().replace(/[{}]/g, '');
                    var expectedId = expectedValue.toLowerCase().replace(/[{}]/g, '');

                    if (lookupId === expectedId) {
                        tabNameToUse = newTabName;
                    }
                }

                // Set the tab name
                tab.setLabel(tabNameToUse);

            } catch (innerError) {
                console.error("Error in updateTabName: " + innerError.message);
            }
        };

        // Add an event handler for when the control field changes
        // The handler will execute immediately due to the true parameter
        addSafeOnChange(formContext, controlFieldName, updateTabName, true);

    } catch (error) {
        console.error("Error in setupConditionalTabRename: " + error.message);
    }
}

/**
 * Setup conditional visibility/requirement based on date field vs due date comparison
 * Shows/requires fields when: (monitored date is empty AND past due date) OR (monitored date > due date)
 * 
 * @param {object} formContext - The form context
 * @param {string} monitoredDateField - The date field to monitor (e.g., "ai_gpfirstapptdate")
 * @param {string} dueDateField - The due date field to compare against (e.g., "ai_6weekcheckduedate") 
 * @param {string|string[]} targetFields - The field(s) to show/hide or make required/optional
 * @param {string} action - Action to perform: "visibility" or "requirement"
 * 
 * Business Logic (always the same):
 * - Show/Require when: (monitored date is empty AND past due date) OR (monitored date > due date)
 * - Hide/Optional when: (monitored date is empty AND within due date) OR (monitored date <= due date)
 * 
 * Example usage:
 * // GP First Appointment barriers - show when not made by 6 weeks or made after 6 weeks
 * AI.FormUtilities.setupDateVsDueDateConditional(
 *     formContext,
 *     "ai_gpfirstapptdate",              // Monitor GP first appointment date
 *     "ai_6weekcheckduedate",            // Against 6-week due date
 *     [                                  // Target fields to show/require
 *         "ai_gpfirstapptbarriers",
 *         "ai_gpfirstapptactions"
 *     ],
 *     "visibility"                       // Show/hide fields
 * );
 */
function setupDateVsDueDateConditional(formContext, monitoredDateField, dueDateField, targetFields, action) {
    try {
        // Validate parameters
        if (!monitoredDateField || !dueDateField) {
            console.error("monitoredDateField and dueDateField are required parameters");
            return;
        }

        var validActions = ['visibility', 'requirement'];
        if (validActions.indexOf(action) === -1) {
            console.error("Action must be one of: " + validActions.join(', '));
            return;
        }

        // The validation function is always the same - no need to pass it as parameter
        var standardDateVsDueDateValidation = function (formContext) {
            var monitoredDate = formContext.getAttribute(monitoredDateField).getValue();
            var dueDate = formContext.getAttribute(dueDateField).getValue();

            // Check if we're past the due date
            var pastDueDate = dueDate && dueDate <= new Date();

            // Check if monitored date is populated
            var hasMonitoredDate = monitoredDate !== null && monitoredDate !== undefined;

            // Check if monitored date is after due date (completed after deadline)
            var completedAfterDueDate = hasMonitoredDate && dueDate && monitoredDate > dueDate;

            // Standard Logic: Show/Require when either condition is met:
            // 1. Not completed and past due date - show fields for barriers/actions
            // 2. Completed after due date - show fields for "achieved later" scenarios
            return (!hasMonitoredDate && pastDueDate) || completedAfterDueDate;
        };

        // Use setupFunctionBasedConditional with our standard validation
        setupFunctionBasedConditional(
            formContext,
            [monitoredDateField, dueDateField],    // Watch both date fields
            standardDateVsDueDateValidation,       // Our standard validation function
            targetFields,                          // Target fields
            action                                 // Action type
        );

        console.log("Date vs Due Date conditional setup complete for " +
            (Array.isArray(targetFields) ? targetFields.join(", ") : targetFields) +
            " monitoring " + monitoredDateField + " against " + dueDateField + " with action: " + action);

    } catch (error) {
        console.error("Error in setupDateVsDueDateConditional: " + error.message);
    }
}

/**
 * Setup conditional lookup view based on polymorphic field entity type with mapping
 * @param {object} formContext - The form context
 * @param {string} polymorphicFieldName - The name of the polymorphic field that controls which view to use
 * @param {string} targetLookupFieldName - The name of the lookup field to change the view for
 * @param {object} viewMapping - Object mapping entity types to view GUIDs. Must include "default" key.
 * 
 * Example usage:
 * // Change lookup view based on polymorphic field entity type
 * AI.FormUtilities.setupPolymorphicLookupView(
 *     formContext,
 *     "regardingobjectid",                   // Polymorphic control field
 *     "customerid",                          // Target lookup field
 *     {                                      // View mapping by entity type
 *         "contact": "12345678-1234-1234-1234-123456789012",
 *         "account": "87654321-4321-4321-4321-210987654321",
 *         "ai_cncase": "51eab5d4-dccf-f011-bbd3-002248e43b84",
 *         "ai_p2ecase": "e980431b-9862-f011-bec2-000d3ae11c0a",
 *         "default": "bd20fcdc-c50b-4e69-944a-cddbe5c0020a"
 *     }
 * );
 */
function setupPolymorphicLookupView(formContext, polymorphicFieldName, targetLookupFieldName, viewMapping) {
    try {
        // Get the polymorphic field
        var polymorphicField = formContext.getAttribute(polymorphicFieldName);

        // Get the target lookup control
        var targetLookupControl = formContext.getControl(targetLookupFieldName);

        // Validate that both fields exist
        if (!polymorphicField) {
            console.log("Polymorphic field " + polymorphicFieldName + " not found on the form");
            return;
        }

        if (!targetLookupControl) {
            console.log("Target lookup control " + targetLookupFieldName + " not found on the form");
            return;
        }

        // Validate view mapping parameter
        if (!viewMapping || typeof viewMapping !== 'object') {
            console.error("viewMapping parameter must be a valid object");
            return;
        }

        if (!viewMapping.default) {
            console.error("viewMapping must include a 'default' key for fallback view");
            return;
        }

        // Function to update the lookup view
        var updateLookupView = function () {
            try {
                var viewGuidToUse = viewMapping.default; // Default fallback

                // Get the polymorphic field value
                var polymorphicValue = polymorphicField.getValue();

                if (polymorphicValue && polymorphicValue.length > 0) {
                    var entityType = polymorphicValue[0].entityType;
                    if (entityType) {
                        // Check if we have a mapping for this entity type (case-insensitive)
                        var entityTypeLower = entityType.toLowerCase();

                        // First try exact match
                        if (viewMapping[entityType]) {
                            viewGuidToUse = viewMapping[entityType];
                        }
                        // Then try lowercase match
                        else if (viewMapping[entityTypeLower]) {
                            viewGuidToUse = viewMapping[entityTypeLower];
                        }
                        // Finally check all keys case-insensitively
                        else {
                            for (var key in viewMapping) {
                                if (key.toLowerCase() === entityTypeLower && key !== 'default') {
                                    viewGuidToUse = viewMapping[key];
                                    break;
                                }
                            }
                        }
                    }
                }

                targetLookupControl.setDefaultView(viewGuidToUse);
                console.log("Polymorphic lookup view updated for " + targetLookupFieldName +
                    " based on " + polymorphicFieldName + " entity type. Using view: " + viewGuidToUse);
            } catch (innerError) {
                console.error("Error in updatePolymorphicLookupView: " + innerError.message);
            }
        };

        // Add an event handler for when the polymorphic field changes
        addSafeOnChange(formContext, polymorphicFieldName, updateLookupView, true);

        console.log("Polymorphic lookup view setup complete for " + targetLookupFieldName +
            " controlled by " + polymorphicFieldName + " with " + Object.keys(viewMapping).length + " view mappings");

    } catch (error) {
        console.error("Error in setupPolymorphicLookupView: " + error.message);
    }
}

// Export functions for use in other scripts
if (typeof window !== 'undefined') {
    // In browser context, add to window object
    window.AI = window.AI || {};
    window.AI.FormUtilities = {
        setupConditionalVisibility: setupConditionalVisibility,
        setupPolymorphicFieldVisibility: setupPolymorphicFieldVisibility,
        setupConditionalLookupView: setupConditionalLookupView,
        setupPolymorphicLookupView: setupPolymorphicLookupView,  
        setupConditionalRequirement: setupConditionalRequirement,
        setupDateConditionalRequirement: setupDateConditionalRequirement,
        setupDateConditionalVisibility: setupDateConditionalVisibility, 
        setupMultiFieldConditionalRequirement: setupMultiFieldConditionalRequirement,
        setupMultiFieldConditionalVisibility: setupMultiFieldConditionalVisibility,
        setupFieldValueOnCondition: setupFieldValueOnCondition,
        setupCopyFieldValueOnCondition: setupCopyFieldValueOnCondition,
        clearFields: clearFields,
        setupTabVisibility: setupTabVisibility,
        setupFieldVisibility: setupFieldVisibility,
        setupFunctionBasedConditional: setupFunctionBasedConditional,
        setupConditionalTabRename: setupConditionalTabRename,
        setupDateVsDueDateConditional: setupDateVsDueDateConditional,
        addSafeOnChange: addSafeOnChange
    };
}
