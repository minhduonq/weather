import 'package:flutter/material.dart';
import '../services/github_service.dart';

class GitHubCommitsScreen extends StatefulWidget {
  const GitHubCommitsScreen({Key? key}) : super(key: key);

  @override
  _GitHubCommitsScreenState createState() => _GitHubCommitsScreenState();
}

class _GitHubCommitsScreenState extends State<GitHubCommitsScreen> {
  List<Map<String, dynamic>> commits = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await GitHubService.getCommits(
        owner: 'minhduonq',
        repo: 'weather',
        perPage: 50,
      );

      setState(() {
        commits = result;
        isLoading = false;
        if (commits.isEmpty) {
          errorMessage = 'Không có commits nào được tìm thấy';
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Lỗi khi tải commits: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Commits'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCommits,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCommits,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (commits.isEmpty) {
      return const Center(
        child: Text('Không có commits nào'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCommits,
      child: ListView.builder(
        itemCount: commits.length,
        itemBuilder: (context, index) {
          final commit = commits[index];
          return _buildCommitItem(commit);
        },
      ),
    );
  }

  Widget _buildCommitItem(Map<String, dynamic> commit) {
    final sha = commit['sha'] ?? '';
    final message = commit['message'] ?? 'No message';
    final author = commit['author'] ?? {};
    final authorName = author['name'] ?? 'Unknown';
    final authorDate = author['date'] ?? '';

    // Lấy dòng đầu tiên của message
    final firstLine = message.split('\n').first;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          firstLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              authorName,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  GitHubService.formatDate(authorDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.commit, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  GitHubService.getShortSha(sha),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showCommitDetails(commit),
      ),
    );
  }

  void _showCommitDetails(Map<String, dynamic> commit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết Commit'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SHA: ${GitHubService.getShortSha(commit['sha'] ?? '')}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Message:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(commit['message'] ?? 'No message'),
              const SizedBox(height: 12),
              Text(
                'Author:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(commit['author']?['name'] ?? 'Unknown'),
              Text(
                commit['author']?['email'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Text(
                'Date:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(GitHubService.formatDate(commit['author']?['date'] ?? '')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
