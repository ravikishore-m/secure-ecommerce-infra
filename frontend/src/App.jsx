import { useEffect, useState } from "react";
import axios from "axios";

const services = ["login", "orders", "payments", "inventory", "catalog"];

function App() {
  const [status, setStatus] = useState({});

  useEffect(() => {
    const controller = new AbortController();
    async function fetchStatus() {
      try {
        const requests = services.map((svc) =>
          axios
            .get(`/api/${svc}/healthz`, { signal: controller.signal })
            .then((resp) => ({ svc, data: resp.data }))
            .catch((error) => ({ svc, error: error.message })),
        );
        const responses = await Promise.all(requests);
        const mapped = responses.reduce((acc, item) => {
          acc[item.svc] = item.error ? { error: item.error } : item.data;
          return acc;
        }, {});
        setStatus(mapped);
      } catch (err) {
        console.error(err);
      }
    }
    fetchStatus();
    return () => controller.abort();
  }, []);

  return (
    <main>
      <header>
        <h1>Secure Ecommerce Platform</h1>
        <p>Zero-trust ready storefront running on AWS EKS</p>
      </header>
      <section className="grid">
        {services.map((svc) => (
          <article key={svc}>
            <h2>{svc}</h2>
            <pre>{JSON.stringify(status[svc] ?? { status: "unknown" }, null, 2)}</pre>
          </article>
        ))}
      </section>
    </main>
  );
}

export default App;

