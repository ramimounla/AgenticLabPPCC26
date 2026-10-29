/**
 * Dynamics 365 CRM Form Utilities
 * 
 * @version 1.0
 */

/**
 * Make a field required when a control field equals a value, otherwise optional.
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The field whose value controls the requirement
 * @param {string} targetFieldName - The field to make required/optional
 * @param {any} expectedValue - The value that makes the target field required
 */
function setupConditionalRequirement(formContext, controlFieldName, targetFieldName, expectedValue) {
    var controlField = formContext.getAttribute(controlFieldName);
    var targetAttribute = formContext.getAttribute(targetFieldName);

    if (!controlField || !targetAttribute) {
        console.log("Field " + controlFieldName + " or " + targetFieldName + " not found on the form");
        return;
    }

    var updateRequirement = function () {
        var isRequired = controlField.getValue() === expectedValue;
        targetAttribute.setRequiredLevel(isRequired ? "required" : "none");
    };

    addSafeOnChange(formContext, controlFieldName, updateRequirement, true);
}

/**
 * Show a field when a control field equals a value, otherwise hide it.
 * When the control field changes and the target becomes hidden, its value is cleared.
 * @param {object} formContext - The form context
 * @param {string} controlFieldName - The field whose value controls visibility
 * @param {string} targetFieldName - The field to show/hide
 * @param {any} expectedValue - The value that makes the target field visible
 */
function setupFieldVisibility(formContext, controlFieldName, targetFieldName, expectedValue) {
    var controlField = formContext.getAttribute(controlFieldName);
    var targetControl = formContext.getControl(targetFieldName);
    var targetAttribute = formContext.getAttribute(targetFieldName);

    if (!controlField || !targetControl || !targetAttribute) {
        console.log("Field " + controlFieldName + " or " + targetFieldName + " not found on the form");
        return;
    }

    var updateVisibility = function () {
        var isVisible = controlField.getValue() === expectedValue;
        targetControl.setVisible(isVisible);

        // Don't clear on load, or opening a record would make the form dirty
        if (!isVisible && targetAttribute.getValue() !== null) {
            targetAttribute.setValue(null);
        }
    };

    addSafeOnChange(formContext, controlFieldName, updateVisibility, true);
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
    var attribute = formContext.getAttribute(fieldName);
    if (!attribute) {
        console.log("Field " + fieldName + " not found on the form");
        return false;
    }

    // One failing handler mustn't stop the others from running
    var runSafely = function (handler) {
        try {
            handler();
        } catch (error) {
            console.error("Error in event handler: " + error.message);
        }
    };

    if (!attribute._onChangeHandlers) {
        attribute._onChangeHandlers = [];
        attribute.addOnChange(function () {
            attribute._onChangeHandlers.forEach(runSafely);
        });
    }

    attribute._onChangeHandlers.push(eventHandler);

    if (executeImmediately !== false) {
        runSafely(eventHandler);
    }
    return true;
}


// Export functions for use in other scripts
if (typeof window !== 'undefined') {
    // In browser context, add to window object
    window.AI = window.AI || {};
    window.AI.FormUtilities = {
        setupFieldVisibility: setupFieldVisibility,
        setupConditionalRequirement: setupConditionalRequirement,
        addSafeOnChange: addSafeOnChange
    };
}
