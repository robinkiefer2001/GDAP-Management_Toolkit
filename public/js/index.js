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
    $('count-relationshipsActive').textContent =
        countActiveRelationships();

    $('count-relationshipsExpired').textContent =
        countExpiredRelationships();

    $('count-relationshipsTerminated').textContent =
        countTerminatedRelationships();
}

initPage(renderIndex);