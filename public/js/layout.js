// Gemeinsames Layout: Navbar (oben) + Footer (unten) für alle Seiten.
// Base-Design hier anpassen – gilt automatisch für jede Seite.

const navItems = [
    { href: 'customers.html', label: 'Customers' },
    { href: 'relationships.html', label: 'Relationships' },
    { href: 'build.html', label: 'Build' },
];

function createPageRefresh(onRefresh) {
    const toolbar = document.createElement('div');
    toolbar.className = 'mb-4 flex justify-end';
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'btn btn-outline btn-sm';
    button.textContent = 'Refresh';
    button.setAttribute('aria-label', 'Daten neu vom Backend laden');
    button.addEventListener('click', onRefresh);
    toolbar.append(button);
    document.querySelector('main').prepend(toolbar);
    return button;
}

function renderLayout() {
    const current = location.pathname.split('/').pop() || 'index.html';

    const header = `
    <div class="navbar bg-base-100 shadow-sm">
        <div class="flex-1">
            <a class="btn btn-ghost text-xl" href="index.html">GDAP Management Toolkit</a>
        </div>
        <div class="flex-none">
            <ul class="menu menu-horizontal px-1 gap-1">
                ${navItems.map((item) => `
                    <li><a class="${item.href === current ? 'menu-active' : ''}" href="${item.href}">${item.label}</a></li>
                `).join('')}
            </ul>
        </div>
    </div>`;

    const footer = `
    <footer class="footer footer-center p-4 opacity-60">
        <p>GDAP Management Toolkit by robinkiefer2001</p>
    </footer>`;

    document.body.insertAdjacentHTML('afterbegin', header);
    document.body.insertAdjacentHTML('beforeend', footer);
}

document.addEventListener('DOMContentLoaded', renderLayout);
