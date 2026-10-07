module.exports = {
  apps: [
    {
      name: "wwjing-server",
      cwd: "./server-node",
      script: "server.js",
      env: {
        NODE_ENV: "production",
        PORT: "3002"
      },
      autorestart: true,
      watch: false,
      max_memory_restart: "300M"
    },
    {
      name: "wwjing-web",
      cwd: "./web",
      script: "node_modules/vite/bin/vite.js",
      args: "--host 0.0.0.0",
      env: {
        NODE_ENV: "development"
      },
      autorestart: true,
      watch: false,
      max_memory_restart: "300M"
    },
    {
      name: "wwjing-server-go",
      cwd: "./server-go",
      script: "./server",
      env: {
        NODE_ENV: "production"
      },
      autorestart: true,
      watch: false,
      max_memory_restart: "300M"
    }
  ]
};
