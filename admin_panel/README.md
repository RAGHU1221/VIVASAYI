# Admin Panel Scaffold

## Setup

The admin panel is a static Bootstrap 5 UI scaffold.

Open `admin_panel/index.html` in a browser to preview the dashboard.

The API defaults to `http://localhost:8000`. To point the panel at a different API origin, set this in the browser console:

```js
localStorage.setItem('vivasayi_admin_api_base_url', 'http://localhost:8000')
```

## Next Steps

- Add create/edit flows for users and farmers
- Add dashboard counts from API summary endpoints
- Extend dashboard widgets and charts
- Display more filters for audit logs from `GET /audit-logs`
