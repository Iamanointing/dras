(function (global) {
  var csrfCache = null;

  function drasGetCsrf() {
    return fetch('/api/auth/session', { credentials: 'include' })
      .then(function (r) {
        if (!r.ok) throw new Error('Session check failed');
        return r.json();
      })
      .then(function (d) {
        if (d.csrfToken) csrfCache = d.csrfToken;
        return csrfCache;
      });
  }

  function drasMe() {
    return fetch('/api/auth/session', { credentials: 'include' }).then(function (r) {
      if (!r.ok) throw new Error('Session check failed');
      return r.json();
    });
  }

  function drasApi(path, opts) {
    opts = opts || {};
    var method = (opts.method || 'GET').toUpperCase();
    var headers = { Accept: 'application/json' };
    var init = { method: method, credentials: 'include', headers: headers };
    if (opts.json !== undefined) {
      headers['Content-Type'] = 'application/json';
      init.body = JSON.stringify(opts.json);
    }
    var token = opts.csrf != null ? opts.csrf : csrfCache;
    if (['POST', 'PUT', 'PATCH', 'DELETE'].indexOf(method) >= 0 && token) {
      headers['X-CSRF-Token'] = token;
    }
    return fetch(path, init).then(function (r) {
      var ct = r.headers.get('content-type') || '';
      var isJson = ct.indexOf('application/json') >= 0;
      return (isJson ? r.json() : r.text()).then(function (body) {
        if (!r.ok) {
          var msg =
            body && typeof body === 'object' && body.error
              ? body.error
              : typeof body === 'string'
                ? body
                : r.statusText;
          throw new Error(msg || 'Request failed');
        }
        return body;
      });
    });
  }

  function drasLogout() {
    return drasGetCsrf().then(function (csrf) {
      return drasApi('/api/auth/logout', { method: 'POST', csrf: csrf });
    });
  }

  global.drasGetCsrf = drasGetCsrf;
  global.drasMe = drasMe;
  global.drasApi = drasApi;
  global.drasLogout = drasLogout;
})(typeof window !== 'undefined' ? window : globalThis);
