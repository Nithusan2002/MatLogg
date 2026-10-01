import { createRoot } from "react-dom/client";
import App from "./App";
import PrivacyPage from "./PrivacyPage";
import "./styles.css";
const root = document.getElementById("root");
if (!root) throw new Error("Missing application root");
const isPrivacy = window.location.pathname.endsWith("/personvern.html");
if (isPrivacy) document.title = "Personvern – MatLogg";
createRoot(root).render(isPrivacy ? <PrivacyPage /> : <App />);

