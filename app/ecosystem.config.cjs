module.exports = {
    apps: [{
        name: 'tv-state-local',
        script: './dist/index.js',
        instances: 1,
        autorestart: true,
        watch: false,
        max_memory_restart: '1G',
        env: {
            NODE_ENV: 'production',
            PORT: 8765
        },
        error_file: './log/err.log',
        out_file: './log/out.log',
        log_file: './log/combined.log',
        time: true
    }]
};
