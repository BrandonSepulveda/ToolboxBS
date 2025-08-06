# ToolboxBS Development Guide

## Overview
ToolboxBS is a comprehensive Windows system optimization and maintenance suite built with PowerShell and modern web technologies. This guide covers development setup, testing, and contribution guidelines.

## Project Structure

```
ToolboxBS/
├── .github/
│   └── workflows/
│       └── blank.yml          # CI/CD pipeline
├── procesos/                  # PowerShell utility scripts
│   ├── infosystem.ps1        # System information gathering
│   ├── Analizador.ps1        # System analyzer
│   ├── instalador de apps.ps1 # App installer
│   ├── pantalla azul.ps1     # Blue screen analyzer
│   ├── windows instalador.ps1 # Windows installer tools
│   └── performance.bat       # Performance utilities
├── index.html                 # Project landing page
├── ToolboxBSweb.html         # Web-based UI interface
├── ToolboxBS.ps1             # PowerShell 7 launcher
├── Tool.ps1                  # Main download and execution script
├── validate.ps1              # Local validation script
├── README.md                 # Project documentation
└── .gitignore               # Git ignore rules
```

## Development Setup

### Prerequisites
- Windows 10/11 (for PowerShell testing)
- PowerShell 5.1 or PowerShell 7+ 
- Git for version control
- A modern web browser for testing HTML interfaces
- (Optional) Visual Studio Code with PowerShell extension

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/BrandonSepulveda/ToolboxBS.git
   cd ToolboxBS
   ```

2. **Install PowerShell validation tools:**
   ```powershell
   Install-Module PSScriptAnalyzer -Scope CurrentUser
   ```

3. **Run local validation:**
   ```powershell
   .\validate.ps1 -Verbose
   ```

### Testing

#### PowerShell Scripts
- Run syntax validation: `.\validate.ps1`
- Test individual scripts manually in PowerShell
- Use PSScriptAnalyzer for code quality checks

#### Web Interface
- Open `index.html` and `ToolboxBSweb.html` in a web browser
- Test functionality and UI responsiveness
- Verify external links work correctly

#### Local Web Server (for testing)
```bash
# Using Python
python -m http.server 8000

# Using Node.js (if available)
npx http-server
```

Then navigate to `http://localhost:8000`

## Code Standards

### PowerShell Scripts
- Use UTF-8 encoding without BOM
- Follow PowerShell best practices
- Include error handling with try/catch blocks
- Use descriptive variable names
- Add comments for complex logic
- Use approved PowerShell verbs for functions

### HTML/CSS/JavaScript
- Use valid HTML5 syntax
- Include proper DOCTYPE declarations
- Ensure responsive design
- Test cross-browser compatibility
- Minimize external dependencies

### Git Workflow
1. Create feature branches from `main`
2. Make focused, atomic commits
3. Run `.\validate.ps1` before committing
4. Submit pull requests for review

## Continuous Integration

The project uses GitHub Actions for CI/CD with the following checks:
- PowerShell syntax validation
- PSScriptAnalyzer code quality analysis
- HTML validation
- Security checks for sensitive data
- File encoding verification

## Security Considerations

- Never commit sensitive data (passwords, keys, tokens)
- Validate all user inputs in PowerShell scripts
- Use secure PowerShell execution policies
- Review external dependencies and links
- Test scripts in isolated environments

## Performance Guidelines

- Optimize PowerShell scripts for speed and memory usage
- Minimize web page load times
- Use efficient algorithms for system information gathering
- Cache results where appropriate
- Test with low-resource systems

## Troubleshooting

### Common Issues

1. **PowerShell Execution Policy Errors**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **BOM Issues in PowerShell Files**
   - Save files as UTF-8 without BOM
   - Use the validation script to detect BOM issues

3. **HTML Display Issues**
   - Check browser developer console for errors
   - Verify all external resources are accessible
   - Test with local web server

### Debugging

- Use PowerShell ISE or VS Code for script debugging
- Enable verbose output in PowerShell scripts
- Use browser developer tools for web interface issues
- Check GitHub Actions logs for CI failures

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run validation tests
5. Submit a pull request

### Pull Request Guidelines
- Provide clear description of changes
- Include screenshots for UI changes
- Ensure all CI checks pass
- Update documentation if needed

## Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)
- [HTML5 Specification](https://html.spec.whatwg.org/)
- [Git Best Practices](https://git-scm.com/doc)

## License

This project is dual-licensed under AGPL v3.0 for open source use and commercial licensing for enterprise use. See `LICENSE` file for details.

---

For questions or support, contact: jhonvaldessepulveda@gmail.com