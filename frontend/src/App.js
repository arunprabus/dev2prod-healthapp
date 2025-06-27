import React, { useState, useEffect } from 'react';

function App() {
  const [health, setHealth] = useState(null);
  const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8080';

  useEffect(() => {
    fetch(`${apiUrl}/api/health`)
      .then(res => res.json())
      .then(data => setHealth(data))
      .catch(err => console.error('API Error:', err));
  }, [apiUrl]);

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial' }}>
      <h1>Health App Frontend</h1>
      <div>
        <h2>API Status:</h2>
        <pre>{JSON.stringify(health, null, 2)}</pre>
      </div>
    </div>
  );
}

export default App;