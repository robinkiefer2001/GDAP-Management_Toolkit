function countActiveRelationships() {
    return gdapData.relationships.filter(
        (relationship) => relationship.relationshipStatus === 'active'
    ).length;
}

function countExpiredRelationships() {
    return gdapData.relationships.filter(
        (relationship) => relationship.relationshipStatus === 'expired'
    ).length;
}

function countTerminatedRelationships() {
    return gdapData.relationships.filter(
        (relationship) => relationship.relationshipStatus === 'terminated'
    ).length;
}

function renderIndex() {
    getElement('countRelationshipsActive').textContent =
        countActiveRelationships();

    getElement('countRelationshipsExpired').textContent =
        countExpiredRelationships();

    getElement('countRelationshipsTerminated').textContent =
        countTerminatedRelationships();
}

initPage(renderIndex);