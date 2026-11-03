// Gemeinsame Helfer + Datenabruf für alle Seiten

let gdapData = null;

const $ = (id) => document.getElementById(id);

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (c) => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
}

function formatDate(value) {
    if (value === null || value === undefined || value === '') {
        return '—';
    }

    let date;

    if (typeof value === 'string' && value.startsWith('/Date(')) {
        // Beispiel: "/Date(1700663158413)/"
        const millisecondsText = value.slice(6, -2);

        const milliseconds = Number(millisecondsText);

        date = new Date(milliseconds);
    } else {
        // Für normale Datumswerte, beispielsweise ISO-Strings.
        date = new Date(value);
    }

    if (isNaN(date.getTime())) {
        return '—';
    }

    return date.toLocaleDateString('de-CH');
}

function statusBadge(status) {
    const s = (status || '').toLowerCase();
    let cls = 'badge-warning';
    if (s === 'active') cls = 'badge-success';
    else if (s === 'terminated' || s === 'expired') cls = 'badge-error';
    return `<span class="badge ${cls} badge-sm">${escapeHtml(status || 'unknown')}</span>`;
}

function roleBadges(roles) {
    if (!roles || !roles.length) return '<span class="text-sm opacity-60">keine Rollen</span>';
    return roles.map((r) => {
        // Anzeigename kommt vom Backend (Get-RoleMapping); Fallback: GUID
        const name = r.RoleDisplayName || r.roleDisplayName || r.RoleDefinitionId || r.roleDefinitionId || 'unbekannt';
        return `<span class="badge badge-outline badge-sm">${escapeHtml(name)}</span>`;
    }).join(' ');
}

function customerNameByTenant(tenantId) {
    const c = ((gdapData && gdapData.customers) || []).find((x) => x.customerTenantId === tenantId);
    return c ? c.customerName : (tenantId || '—');
}

async function loadGdapData() {
    // 1. Bereits im Speicher dieser Seite vorhanden?
    if (gdapData !== null) {
        return gdapData;
    }

    // 2. Bereits durch eine vorherige Seite im Tab gespeichert?
    try {
        const savedData = sessionStorage.getItem('gdapData');

        if (savedData !== null) {
            gdapData = JSON.parse(savedData);
            return gdapData;
        }
    } catch (error) {
        console.warn('Browser-Cache konnte nicht gelesen werden:', error);
    }

    // 3. Noch keine Daten vorhanden: beim Backend abrufen.
    const res = await fetch('/api/data');

    if (!res.ok) {
        const body = await res.json().catch(() => null);

        throw new Error(
            (body && body.error) || ('HTTP ' + res.status)
        );
    }

    gdapData = await res.json();

    // 4. Für nachfolgende Seiten im selben Tab speichern.
    try {
        sessionStorage.setItem(
            'gdapData',
            JSON.stringify(gdapData)
        );
    } catch (error) {
        console.warn('Browser-Cache konnte nicht gespeichert werden:', error);
    }

    return gdapData;
}

// Standard-Initialisierung einer Datenseite:
// lädt /api/data, blendet #loading aus und ruft die Render-Funktion der Seite auf.
async function initPage(render) {
    try {
        await loadGdapData();
        $('loading').classList.add('hidden');
        $('content').classList.remove('hidden');
        render();
    } catch (e) {
        $('loading').classList.add('hidden');
        $('error-text').textContent =
            'Daten konnten nicht geladen werden: ' + e.message +
            ' — Wurde der Server in einer Session mit aktiver Graph-Verbindung (Connect-MgGraph) gestartet?';
        $('error').classList.remove('hidden');
    }
}
