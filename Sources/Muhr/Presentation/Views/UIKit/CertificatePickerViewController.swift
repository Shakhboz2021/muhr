//
//  CertificatePickerViewController.swift
//  Muhr
//
//  Created by Muhammad on 29/01/26.
//

#if os(iOS)
    import UIKit
    import Combine

    // MARK: - Certificate Picker ViewController
    @available(iOS 13.0, *)
    public final class CertificatePickerViewController: UIViewController {

        // MARK: - Properties

        private let viewModel = CertificatePickerViewModel()
        private var cancellables = Set<AnyCancellable>()

        // MARK: - Callbacks

        public var onInstallSuccess: ((CertificateInfo) -> Void)?
        public var onCancel: (() -> Void)?

        // MARK: - UI Components

        private lazy var tableView: UITableView = {
            let table = UITableView(frame: .zero, style: .plain)
            table.translatesAutoresizingMaskIntoConstraints = false
            table.delegate = self
            table.dataSource = self
            table.register(
                CertificateFileCell.self,
                forCellReuseIdentifier: CertificateFileCell.identifier
            )
            table.rowHeight = 60
            return table
        }()

        private lazy var emptyStateView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.isHidden = true

            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.alignment = .center
            stackView.spacing = 16
            stackView.translatesAutoresizingMaskIntoConstraints = false

            let imageView = UIImageView(
                image: UIImage(systemName: "doc.badge.plus")
            )
            imageView.tintColor = .secondaryLabel
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 60).isActive =
                true
            imageView.heightAnchor.constraint(equalToConstant: 60).isActive =
                true

            let titleLabel = UILabel()
            titleLabel.text = "Сертификат топилмади"
            titleLabel.font = .preferredFont(forTextStyle: .headline)

            let subtitleLabel = UILabel()
            subtitleLabel.text =
                "Documents папкасига .p12 ёки .pfx файлни қўшинг"
            subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.textAlignment = .center
            subtitleLabel.numberOfLines = 0

            stackView.addArrangedSubview(imageView)
            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(subtitleLabel)

            view.addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                stackView.leadingAnchor.constraint(
                    greaterThanOrEqualTo: view.leadingAnchor,
                    constant: 32
                ),
                stackView.trailingAnchor.constraint(
                    lessThanOrEqualTo: view.trailingAnchor,
                    constant: -32
                ),
            ])

            return view
        }()

        private lazy var bottomContainerView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .systemBackground
            return view
        }()

        private lazy var passwordTextField: UITextField = {
            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.placeholder = "Сертификат пароли"
            textField.isSecureTextEntry = true
            textField.borderStyle = .roundedRect
            textField.addTarget(
                self,
                action: #selector(passwordChanged),
                for: .editingChanged
            )
            return textField
        }()

        private lazy var errorLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .systemRed
            label.font = .preferredFont(forTextStyle: .caption1)
            label.isHidden = true
            label.numberOfLines = 0
            return label
        }()

        private lazy var installButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Ўрнатиш", for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.setTitleColor(.lightGray, for: .disabled)
            button.layer.cornerRadius = 10
            button.isEnabled = false
            button.addTarget(
                self,
                action: #selector(installTapped),
                for: .touchUpInside
            )
            return button
        }()

        private lazy var activityIndicator: UIActivityIndicatorView = {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.hidesWhenStopped = true
            indicator.color = .white
            return indicator
        }()

        private lazy var separatorView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .separator
            return view
        }()

        // MARK: - Lifecycle

        public override func viewDidLoad() {
            super.viewDidLoad()
            setupUI()
            setupNavigationBar()
            bindViewModel()

            Task { @MainActor in
                viewModel.loadFiles()
            }
        }

        // MARK: - Setup

        private func setupUI() {
            view.backgroundColor = .systemBackground

            view.addSubview(tableView)
            view.addSubview(emptyStateView)
            view.addSubview(separatorView)
            view.addSubview(bottomContainerView)

            bottomContainerView.addSubview(passwordTextField)
            bottomContainerView.addSubview(errorLabel)
            bottomContainerView.addSubview(installButton)
            installButton.addSubview(activityIndicator)

            NSLayoutConstraint.activate([
                // Table view
                tableView.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor
                ),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor
                ),
                tableView.bottomAnchor.constraint(
                    equalTo: separatorView.topAnchor
                ),

                // Empty state
                emptyStateView.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor
                ),
                emptyStateView.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor
                ),
                emptyStateView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor
                ),
                emptyStateView.bottomAnchor.constraint(
                    equalTo: separatorView.topAnchor
                ),

                // Separator
                separatorView.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor
                ),
                separatorView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor
                ),
                separatorView.bottomAnchor.constraint(
                    equalTo: bottomContainerView.topAnchor
                ),
                separatorView.heightAnchor.constraint(equalToConstant: 1),

                // Bottom container
                bottomContainerView.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor
                ),
                bottomContainerView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor
                ),
                bottomContainerView.bottomAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.bottomAnchor
                ),

                // Password text field
                passwordTextField.topAnchor.constraint(
                    equalTo: bottomContainerView.topAnchor,
                    constant: 16
                ),
                passwordTextField.leadingAnchor.constraint(
                    equalTo: bottomContainerView.leadingAnchor,
                    constant: 16
                ),
                passwordTextField.trailingAnchor.constraint(
                    equalTo: bottomContainerView.trailingAnchor,
                    constant: -16
                ),
                passwordTextField.heightAnchor.constraint(equalToConstant: 44),

                // Error label
                errorLabel.topAnchor.constraint(
                    equalTo: passwordTextField.bottomAnchor,
                    constant: 8
                ),
                errorLabel.leadingAnchor.constraint(
                    equalTo: bottomContainerView.leadingAnchor,
                    constant: 16
                ),
                errorLabel.trailingAnchor.constraint(
                    equalTo: bottomContainerView.trailingAnchor,
                    constant: -16
                ),

                // Install button
                installButton.topAnchor.constraint(
                    equalTo: errorLabel.bottomAnchor,
                    constant: 16
                ),
                installButton.leadingAnchor.constraint(
                    equalTo: bottomContainerView.leadingAnchor,
                    constant: 16
                ),
                installButton.trailingAnchor.constraint(
                    equalTo: bottomContainerView.trailingAnchor,
                    constant: -16
                ),
                installButton.bottomAnchor.constraint(
                    equalTo: bottomContainerView.bottomAnchor,
                    constant: -16
                ),
                installButton.heightAnchor.constraint(equalToConstant: 50),

                // Activity indicator
                activityIndicator.centerXAnchor.constraint(
                    equalTo: installButton.centerXAnchor
                ),
                activityIndicator.centerYAnchor.constraint(
                    equalTo: installButton.centerYAnchor
                ),
            ])
        }

        private func setupNavigationBar() {
            title = "Сертификат ўрнатиш"
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Бекор",
                style: .plain,
                target: self,
                action: #selector(cancelTapped)
            )
        }

        // MARK: - Binding

        private func bindViewModel() {
            viewModel.$files
                .receive(on: DispatchQueue.main)
                .sink { [weak self] files in
                    self?.tableView.reloadData()
                    self?.emptyStateView.isHidden = !files.isEmpty
                    self?.tableView.isHidden = files.isEmpty
                }
                .store(in: &cancellables)

            viewModel.$selectedFile
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.tableView.reloadData()
                    self?.updateInstallButton()
                }
                .store(in: &cancellables)

            viewModel.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.handleStateChange(state)
                }
                .store(in: &cancellables)

            viewModel.onInstallSuccess = { [weak self] cert in
                self?.onInstallSuccess?(cert)
            }

            viewModel.onCancel = { [weak self] in
                self?.onCancel?()
            }
        }

        // MARK: - State Handling

        private func handleStateChange(_ state: CertificateInstallState) {
            switch state {
            case .idle:
                setLoading(false)
                errorLabel.isHidden = true

            case .loading:
                setLoading(true)
                errorLabel.isHidden = true

            case .success:
                setLoading(false)
                errorLabel.isHidden = true

            case .error(let message):
                setLoading(false)
                errorLabel.text = message
                errorLabel.isHidden = false
            }
        }

        private func setLoading(_ isLoading: Bool) {
            installButton.setTitle(isLoading ? "" : "Ўрнатиш", for: .normal)
            installButton.isEnabled = !isLoading && viewModel.canInstall
            passwordTextField.isEnabled = !isLoading

            if isLoading {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }

        private func updateInstallButton() {
            installButton.isEnabled = viewModel.canInstall
            installButton.backgroundColor =
                viewModel.canInstall ? .systemBlue : .systemGray4
        }

        // MARK: - Actions

        @objc private func cancelTapped() {
            viewModel.cancel()
        }

        @objc private func installTapped() {
            Task {
                await viewModel.install()
            }
        }

        @objc private func passwordChanged() {
            viewModel.password = passwordTextField.text ?? ""
            updateInstallButton()
        }
    }

    // MARK: - UITableViewDataSource
    @available(iOS 13.0, *)
    extension CertificatePickerViewController: UITableViewDataSource {

        public func tableView(
            _ tableView: UITableView,
            numberOfRowsInSection section: Int
        ) -> Int {
            return viewModel.files.count
        }

        public func tableView(
            _ tableView: UITableView,
            cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell {
            guard
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CertificateFileCell.identifier,
                    for: indexPath
                ) as? CertificateFileCell
            else {
                return UITableViewCell()
            }

            let file = viewModel.files[indexPath.row]
            let isSelected = viewModel.selectedFile?.id == file.id
            cell.configure(with: file, isSelected: isSelected)

            return cell
        }
    }

    // MARK: - UITableViewDelegate
    @available(iOS 13.0, *)
    extension CertificatePickerViewController: UITableViewDelegate {

        public func tableView(
            _ tableView: UITableView,
            didSelectRowAt indexPath: IndexPath
        ) {
            tableView.deselectRow(at: indexPath, animated: true)
            viewModel.selectedFile = viewModel.files[indexPath.row]
        }
    }

    // MARK: - Certificate File Cell
    @available(iOS 13.0, *)
    final class CertificateFileCell: UITableViewCell {

        static let identifier = "CertificateFileCell"

        // MARK: - UI Components

        private let iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.image = UIImage(systemName: "doc.badge.lock.fill")
            imageView.tintColor = .systemBlue
            imageView.contentMode = .scaleAspectFit
            return imageView
        }()

        private let nameLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .body)
            return label
        }()

        private let sizeLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .preferredFont(forTextStyle: .caption1)
            label.textColor = .secondaryLabel
            return label
        }()

        private let checkmarkImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.image = UIImage(systemName: "checkmark.circle.fill")
            imageView.tintColor = .systemGreen
            imageView.contentMode = .scaleAspectFit
            imageView.isHidden = true
            return imageView
        }()

        // MARK: - Init

        override init(
            style: UITableViewCell.CellStyle,
            reuseIdentifier: String?
        ) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            setupUI()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setupUI() {
            contentView.addSubview(iconImageView)
            contentView.addSubview(nameLabel)
            contentView.addSubview(sizeLabel)
            contentView.addSubview(checkmarkImageView)

            NSLayoutConstraint.activate([
                iconImageView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 16
                ),
                iconImageView.centerYAnchor.constraint(
                    equalTo: contentView.centerYAnchor
                ),
                iconImageView.widthAnchor.constraint(equalToConstant: 32),
                iconImageView.heightAnchor.constraint(equalToConstant: 32),

                nameLabel.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 12
                ),
                nameLabel.leadingAnchor.constraint(
                    equalTo: iconImageView.trailingAnchor,
                    constant: 12
                ),
                nameLabel.trailingAnchor.constraint(
                    equalTo: checkmarkImageView.leadingAnchor,
                    constant: -12
                ),

                sizeLabel.topAnchor.constraint(
                    equalTo: nameLabel.bottomAnchor,
                    constant: 4
                ),
                sizeLabel.leadingAnchor.constraint(
                    equalTo: nameLabel.leadingAnchor
                ),
                sizeLabel.trailingAnchor.constraint(
                    equalTo: nameLabel.trailingAnchor
                ),

                checkmarkImageView.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -16
                ),
                checkmarkImageView.centerYAnchor.constraint(
                    equalTo: contentView.centerYAnchor
                ),
                checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
                checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            ])
        }

        // MARK: - Configure

        func configure(with file: CertificateFile, isSelected: Bool) {
            nameLabel.text = file.name
            sizeLabel.text = file.formattedSize
            checkmarkImageView.isHidden = !isSelected
        }
    }
#endif
