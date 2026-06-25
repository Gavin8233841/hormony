import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#eef6ff",
          100: "#d9eaff",
          500: "#2b7fff",
          600: "#1a6bef",
          700: "#1559c9",
        },
      },
    },
  },
  plugins: [],
};

export default config;
