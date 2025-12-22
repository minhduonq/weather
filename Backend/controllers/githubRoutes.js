const express = require('express');
const axios = require('axios');
const router = express.Router();

// Lấy danh sách commits từ GitHub repository
router.get('/commits', async (req, res) => {
    const owner = req.query.owner || 'minhduonq';
    const repo = req.query.repo || 'weather';
    const page = req.query.page || 1;
    const perPage = req.query.per_page || 30;
    
    try {
        const url = `https://api.github.com/repos/${owner}/${repo}/commits`;
        const response = await axios.get(url, {
            params: {
                page: page,
                per_page: perPage
            },
            headers: {
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'Weather-App'
            }
        });
        
        // Chuyển đổi dữ liệu để dễ sử dụng hơn
        const commits = response.data.map(commit => ({
            sha: commit.sha,
            message: commit.commit.message,
            author: {
                name: commit.commit.author.name,
                email: commit.commit.author.email,
                date: commit.commit.author.date
            },
            committer: {
                name: commit.commit.committer.name,
                date: commit.commit.committer.date
            },
            url: commit.html_url
        }));
        
        res.json({
            success: true,
            commits: commits,
            count: commits.length
        });
    } catch (error) {
        console.error('Error fetching GitHub commits:', error.message);
        res.status(500).json({ 
            success: false,
            error: 'Failed to fetch GitHub commits',
            message: error.message 
        });
    }
});

// Lấy chi tiết một commit cụ thể
router.get('/commits/:sha', async (req, res) => {
    const owner = req.query.owner || 'minhduonq';
    const repo = req.query.repo || 'weather';
    const sha = req.params.sha;
    
    try {
        const url = `https://api.github.com/repos/${owner}/${repo}/commits/${sha}`;
        const response = await axios.get(url, {
            headers: {
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'Weather-App'
            }
        });
        
        const commit = {
            sha: response.data.sha,
            message: response.data.commit.message,
            author: {
                name: response.data.commit.author.name,
                email: response.data.commit.author.email,
                date: response.data.commit.author.date
            },
            committer: {
                name: response.data.commit.committer.name,
                date: response.data.commit.committer.date
            },
            files: response.data.files ? response.data.files.map(file => ({
                filename: file.filename,
                status: file.status,
                additions: file.additions,
                deletions: file.deletions,
                changes: file.changes
            })) : [],
            stats: response.data.stats,
            url: response.data.html_url
        };
        
        res.json({
            success: true,
            commit: commit
        });
    } catch (error) {
        console.error('Error fetching commit details:', error.message);
        res.status(500).json({ 
            success: false,
            error: 'Failed to fetch commit details',
            message: error.message 
        });
    }
});

router.get('/', (req, res) => {
    res.json({ 
        message: 'Welcome to the GitHub API!',
        endpoints: [
            'GET /commits - Lấy danh sách commits',
            'GET /commits/:sha - Lấy chi tiết một commit'
        ]
    });
});

module.exports = router;
